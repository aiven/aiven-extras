#include "postgres.h"
#include "fmgr.h"

#include "access/htup_details.h"
#include "catalog/pg_subscription.h"
#include "lib/stringinfo.h"
#include "miscadmin.h"
#include "nodes/parsenodes.h"
#include "nodes/plannodes.h"
#include "parser/parser.h"
#include "tcop/dest.h"
#include "tcop/utility.h"
#include "utils/builtins.h"
#include "utils/acl.h"
#include "utils/memutils.h"
#include "utils/syscache.h"

PG_FUNCTION_INFO_V1(subscription_refresh);

/*
 * Ownership check for the subscription about to be refreshed.
 *
 * PG 16+: the function runs as the caller, and the caller must own the
 * subscription (superusers pass), the same rule AlterSubscription() applies.
 *
 * Before PG 16 the SQL function is SECURITY DEFINER and only superusers can own
 * subscriptions, so GetUserId() is the function owner here.  Only subscriptions
 * owned by that role (the ones created through aiven_extras.pg_create_subscription())
 * may be refreshed; subscriptions of other roles are refused.
 */
static void
check_subscription_owner(const char *subname)
{
	NameData	name;
	HeapTuple	tup;
	Form_pg_subscription form;
	Oid			subowner;
#if PG_VERSION_NUM >= 160000
	Oid			subid;
#endif

	namestrcpy(&name, subname);
	tup = SearchSysCache2(SUBSCRIPTIONNAME,
						  ObjectIdGetDatum(MyDatabaseId),
						  NameGetDatum(&name));
	if (!HeapTupleIsValid(tup))
		ereport(ERROR,
				(errcode(ERRCODE_UNDEFINED_OBJECT),
				 errmsg("subscription \"%s\" does not exist", NameStr(name))));

	form = (Form_pg_subscription) GETSTRUCT(tup);
	subowner = form->subowner;
#if PG_VERSION_NUM >= 160000
	subid = form->oid;
#endif
	ReleaseSysCache(tup);

#if PG_VERSION_NUM >= 160000
	if (!object_ownercheck(SubscriptionRelationId, subid, GetUserId()))
		aclcheck_error(ACLCHECK_NOT_OWNER, OBJECT_SUBSCRIPTION, NameStr(name));
#else
	if (subowner != GetUserId())
		ereport(ERROR,
				(errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
				 errmsg("permission denied to refresh subscription \"%s\"", NameStr(name)),
				 errdetail("The subscription is not owned by the owner of this function.")));
#endif
	(void) subowner;
}

/*
 * Run ALTER SUBSCRIPTION ... REFRESH PUBLICATION in this backend.
 *
 * SQL entry point: aiven_extras.pg_alter_subscription_refresh_publication().
 * Executing the command here keeps the refresh inside the calling session.
 * Before PG 16 the SQL function is SECURITY DEFINER (only superusers can alter
 * subscriptions); on PG 16+ it runs as the caller and PostgreSQL's own
 * ownership check on the subscription applies.
 */
Datum
subscription_refresh(PG_FUNCTION_ARGS)
{
	MemoryContext workctx;
	MemoryContext oldctx;

	/* The SQL declaration is not STRICT, so reject NULLs explicitly. */
	if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
		ereport(ERROR,
				(errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
				 errmsg("subscription name and copy_data must not be null")));

	workctx = AllocSetContextCreate(CurrentMemoryContext,
									"subscription_refresh",
									ALLOCSET_DEFAULT_SIZES);
	oldctx = MemoryContextSwitchTo(workctx);

	PG_TRY();
	{
		char	   *subname;
		bool		copy_data;
		StringInfoData sql;
		List	   *raw;
		RawStmt    *rs;
		PlannedStmt *pstmt;

		subname = text_to_cstring(PG_GETARG_TEXT_PP(0));
		copy_data = PG_GETARG_BOOL(1);

		initStringInfo(&sql);
		appendStringInfo(&sql,
						 "ALTER SUBSCRIPTION %s "
						 "REFRESH PUBLICATION WITH (copy_data = %s)",
						 quote_identifier(subname),
						 copy_data ? "true" : "false");

#if PG_VERSION_NUM >= 140000
		raw = raw_parser(sql.data, RAW_PARSE_DEFAULT);
#else
		raw = raw_parser(sql.data);
#endif

		if (list_length(raw) != 1)
			elog(ERROR, "expected exactly one utility statement");

		rs = linitial_node(RawStmt, raw);

		if (!IsA(rs->stmt, AlterSubscriptionStmt))
			elog(ERROR, "expected ALTER SUBSCRIPTION");

		check_subscription_owner(((AlterSubscriptionStmt *) rs->stmt)->subname);

		pstmt = makeNode(PlannedStmt);
		pstmt->commandType = CMD_UTILITY;
		pstmt->canSetTag = false;
		pstmt->utilityStmt = rs->stmt;
		pstmt->stmt_location = rs->stmt_location;
		pstmt->stmt_len = rs->stmt_len;

#if PG_VERSION_NUM >= 140000
		ProcessUtility(pstmt, sql.data, false,
					   PROCESS_UTILITY_TOPLEVEL,
					   NULL, NULL, None_Receiver, NULL);
#else
		ProcessUtility(pstmt, sql.data,
					   PROCESS_UTILITY_QUERY,
					   NULL, NULL, None_Receiver, NULL);
#endif
	}
	PG_CATCH();
	{
		MemoryContextSwitchTo(oldctx);
		MemoryContextDelete(workctx);
		PG_RE_THROW();
	}
	PG_END_TRY();

	MemoryContextSwitchTo(oldctx);
	MemoryContextDelete(workctx);

	PG_RETURN_VOID();
}
