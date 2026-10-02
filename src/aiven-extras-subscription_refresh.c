#include "postgres.h"
#include "fmgr.h"

#include "lib/stringinfo.h"
#include "nodes/parsenodes.h"
#include "nodes/plannodes.h"
#include "parser/parser.h"
#include "tcop/dest.h"
#include "tcop/utility.h"
#include "utils/builtins.h"
#include "utils/memutils.h"

PG_FUNCTION_INFO_V1(subscription_refresh);

/*
 * Run ALTER SUBSCRIPTION ... REFRESH PUBLICATION in this backend.
 *
 * This replaces a dblink loopback that authenticated as a passwordless local
 * superuser. Executing the command here keeps the refresh inside the calling
 * session, so it no longer depends on trust/peer authentication.
 */
Datum
subscription_refresh(PG_FUNCTION_ARGS)
{
	MemoryContext workctx;
	MemoryContext oldctx;

	/* Defensive: the SQL declaration is STRICT, so this should not happen. */
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
