###
SQL EXPLAIN analysis hook for mysql2

Automatically runs EXPLAIN on all explainable queries. Keeps a journal of JSON EXPLAIN output for auditing.
Provides method `auditAndReset()` which throws if any problems were found in any queries run up to that
point.

This module must be enabled (call the `enable()` method), or it does nothing. Disable with the `disable()`
method.

BDD integration test example:

```
	describe 'module under test', ->
		before ->
			sqlAnalyzer.enable()

		afterEach ->
			sqlAnalyzer.auditAndReset()

		after ->
			sqlAnalyzer.disable()

		it 'example test case...', ->
			# run some code that calls mysql2's Connection#query()
###

runChecks = require './check-runner'
Connection = require 'mysql2/lib/connection'
origConnectionQuery = Connection.prototype.query
log = []

analyzerShim = (query, params..., callback) ->
	q = query?.sql ? query
	p = query?.values ? params[0]

	if q.trim().split(/\s+/).shift().toUpperCase() in ['SELECT', 'DELETE', 'INSERT', 'REPLACE', 'UPDATE']
		explain = "EXPLAIN FORMAT=JSON #{q}"
		origConnectionQuery.call this, explain, p, (err, rows) ->
			if err?
				log.push {query: q, params: p, error: err}
			else
				try
					explanation = JSON.parse rows?[0]?.EXPLAIN
				catch e
					log.push {query: q, params: p, error: e}

				log.push {query: q, params: p, explanation}

	origConnectionQuery.call this, query, params..., callback

audit = (entry) ->
	{errors, warnings} = runChecks entry

	{
		errors
		warnings
		ok: errors.length + warnings.length is 0
		expectOk: ->
			return if errors.length + warnings.length is 0
			messages = []

			messages.push 'SQL Analyzer detected problems in a query'
			messages.push "#{errors.length} error(s) and #{warnings.length} warning(s)"

			for error, idx in errors
				messages.push "Error ##{idx + 1}: #{error.message}"

			for warning, idx in warnings
				messages.push "Warning ##{idx + 1}: #{warning.message}"

			messages.push "Query:\n#{entry.query.split('\n').map((x) -> ">\t#{x}").join('\n')}"
			messages.push "Params: [#{(entry.params ? []).join ', '}]"

			throw new Error messages.join('\n\n')
	}

module.exports = analyzer =
	enable: ->
		Connection.prototype.query = analyzerShim
		return analyzer

	disable: ->
		Connection.prototype.query = origConnectionQuery
		return analyzer

	isEnabled: -> Connection.prototype.query is analyzerShim

	# convenience method; feel free to use #enable(), #disable(), #audit(), #flushLog(), #auditAndReset() instead
	setupTestHooks: (hooks) ->
		if typeof hooks.before is 'function'
			hooks.before -> analyzer.enable()

		if typeof hooks.after is 'function'
			hooks.after -> analyzer.disable()

		if typeof hooks.afterEach is 'function'
			hooks.afterEach -> analyzer.auditAndReset()

	log: -> log.slice()

	flushLog: ->
		log = []
		return analyzer

	auditDetails: ->
		auditResults = log.map (entry) ->
			entry.audit = audit entry if entry.explanation?
			return entry

		auditResults.expectOk = ->
			auditResults.forEach (result) -> result.audit.expectOk()
			return auditResults

		auditResults.flushLog = ->
			analyzer.flushLog()
			return auditResults

		auditResults

	auditAndReset: ->
		analyzer.auditDetails().expectOk().flushLog()
		return analyzer
