#include "postgres.h"
#include "fmgr.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "access/xlogreader.h"
#include "access/xlogutils.h"
#include "replication/logical.h"
#include "replication/slot.h"
#include "replication/walreceiver.h"
#if PG_VERSION_NUM >= 120000 && PG_VERSION_NUM < 130000
#include "replication/logicalfuncs.h"
#endif
#include "utils/pg_lsn.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(standby_slot_create);
	Datum
standby_slot_create(PG_FUNCTION_ARGS)
{
	Name		name = PG_GETARG_NAME(0);
	Name		plugin = PG_GETARG_NAME(1);
	bool		temporary = PG_GETARG_BOOL(2);
	bool		two_phase = PG_GETARG_BOOL(3);
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
	ReplicationSlotCreate(NameStr(*name), true,
			temporary ? RS_TEMPORARY : RS_EPHEMERAL
#if PG_VERSION_NUM >= 140000
			, two_phase
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
