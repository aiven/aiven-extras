#include "postgres.h"
#include "fmgr.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "storage/freespace.h"
#include "storage/smgr.h"
#if PG_VERSION_NUM >= 160000
#include "access/relation.h"
#endif
#include "access/xloginsert.h"
#include "access/xlogreader.h"
#include "access/xlogutils.h"
#include "replication/logical.h"
#include "catalog/storage_xlog.h"
#include "replication/slot.h"
#include "replication/walreceiver.h"
#if PG_VERSION_NUM >= 120000 && PG_VERSION_NUM < 130000
#include "replication/logicalfuncs.h"
#endif
#include "utils/pg_lsn.h"
#include "utils/rel.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(standby_slot_create);
PG_FUNCTION_INFO_V1(aiven_truncate_freespace_map);
	Datum
standby_slot_create(PG_FUNCTION_ARGS)
{
	Name		name = PG_GETARG_NAME(0);
	Name		plugin = PG_GETARG_NAME(1);
	bool		temporary = PG_GETARG_BOOL(2);
	bool		two_phase = PG_GETARG_BOOL(3);
	bool		failover = PG_GETARG_BOOL(4);
	bool		synced = PG_GETARG_BOOL(5);
	Datum		result;
	TupleDesc	tupdesc;
	HeapTuple	tuple;
	Datum		values[2];
	bool		nulls[2];
	LogicalDecodingContext *ctx = NULL;

	if(!RecoveryInProgress())
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("This function can only be used on a standby server.")));

	/*
	 * FIXME: add a ProcessUtility hook disallowing to turn hot_standby_feedback off.
	 * This will require loading through shared_preload_libraries though.
	 */
	if(!hot_standby_feedback)
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("Logical replication slots on a standby require hot_standby_feedback set to 'on'")));

	if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
		elog(ERROR, "return type must be a row type");

	if (!superuser() && !has_rolreplication(GetUserId()))
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("must be superuser or replication role to use replication slots")));

	CheckSlotRequirements();
	if (wal_level < WAL_LEVEL_LOGICAL)
		ereport(ERROR,
				(errcode(ERRCODE_OBJECT_NOT_IN_PREREQUISITE_STATE),
				 errmsg("logical decoding requires wal_level >= logical")));

	if (MyDatabaseId == InvalidOid)
		ereport(ERROR,
				(errcode(ERRCODE_OBJECT_NOT_IN_PREREQUISITE_STATE),
				 errmsg("logical decoding requires a database connection")));
#if PG_VERSION_NUM < 140000
	if (two_phase)
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("two phase commits are only available on PG >= 14")));
#endif
#if PG_VERSION_NUM < 17000
	if (failover)
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("failover is only available on PG >= 17")));
	if (synced)
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("synced is only available on PG >= 17")));
#endif
	/* Don't bother returning anything else than void for now */
	Assert(!MyReplicationSlot);

	/*
	 * Acquire a logical decoding slot, this will check for conflicting names.
	 * Initially create persistent slot as ephemeral - that allows us to
	 * nicely handle errors during initialization because it'll get dropped if
	 * this transaction fails. We'll make it persistent at the end. Temporary
	 * slots can be created as temporary from beginning as they get dropped on
	 * error as well.
	 */
	ReplicationSlotCreate(
	        NameStr(*name),
	        true,
			temporary ? RS_TEMPORARY : RS_EPHEMERAL
#if PG_VERSION_NUM >= 140000
			, two_phase
#endif
#if PG_VERSION_NUM >= 170000
			, failover
			, synced
#endif
			);

	/*
	 * Create logical decoding context to find start point or, if we don't
	 * need it, to 1) bump slot's restart_lsn and xmin 2) check plugin sanity.
	 *
	 * Note: when !find_startpoint this is still important, because it's at
	 * this point that the output plugin is validated.
	 */
	ctx = CreateInitDecodingContext(NameStr(*plugin), NIL,
			false,	/* just catalogs is OK */
			InvalidXLogRecPtr,
#if PG_VERSION_NUM >= 130000
			XL_ROUTINE(.page_read = read_local_xlog_page,
				.segment_open = wal_segment_open,
				.segment_close = wal_segment_close),
#elif PG_VERSION_NUM >= 120000
			logical_read_local_xlog_page,
#endif
			NULL, NULL, NULL);

	/* don't need the decoding context anymore */
	FreeDecodingContext(ctx);

	values[0] = NameGetDatum(&MyReplicationSlot->data.name);
	values[1] = LSNGetDatum(MyReplicationSlot->data.confirmed_flush);

	memset(nulls, 0, sizeof(nulls));

	tuple = heap_form_tuple(tupdesc, values, nulls);
	result = HeapTupleGetDatum(tuple);

	if (!temporary)
		ReplicationSlotPersist();
	ReplicationSlotRelease();
	PG_RETURN_DATUM(result);
}



#if PG_VERSION_NUM >= 160000
Datum
aiven_truncate_freespace_map(PG_FUNCTION_ARGS)
{
	Oid			relid = PG_GETARG_OID(0);
	Relation	rel;
	ForkNumber	fork;
	BlockNumber block;

	rel = relation_open(relid, AccessExclusiveLock);

	/* Only some relkinds have a freespacemap map */
	if (!RELKIND_HAS_TABLE_AM(rel->rd_rel->relkind))
		ereport(ERROR,
				(errcode(ERRCODE_WRONG_OBJECT_TYPE),
				 errmsg("relation \"%s\" is of wrong relation kind",
						RelationGetRelationName(rel)),
				 errdetail_relkind_not_supported(rel->rd_rel->relkind)));


	/* Forcibly reset cached file size */
	RelationGetSmgr(rel)->smgr_cached_nblocks[FSM_FORKNUM] = InvalidBlockNumber;

	/* Just pretend we're going to wipeout the whole rel */
	block = FreeSpaceMapPrepareTruncateRel(rel, 0);

	if (BlockNumberIsValid(block))
	{
		fork = FSM_FORKNUM;
		smgrtruncate(RelationGetSmgr(rel), &fork, 1, &block);
	}

	if (RelationNeedsWAL(rel))
	{
		xl_smgr_truncate xlrec;

		xlrec.blkno = 0;
		xlrec.rlocator = rel->rd_locator;
		xlrec.flags = SMGR_TRUNCATE_FSM;

		XLogBeginInsert();
		XLogRegisterData((char *) &xlrec, sizeof(xlrec));

		XLogInsert(RM_SMGR_ID, XLOG_SMGR_TRUNCATE | XLR_SPECIAL_REL_UPDATE);
	}

	relation_close(rel, AccessExclusiveLock);

	PG_RETURN_VOID();
}
#else
Datum
aiven_truncate_freespace_map(PG_FUNCTION_ARGS)
{
	elog(ERROR, "aiven_truncate_freespace_map is not supported on this version.");
}
#endif
