checks = require './checks/'

module.exports = (entry) ->
	errors = []
	warnings = []

	result =
		error: (msg) ->
			errors.push {
				message: msg
				query: entry.query
				params: entry.params
				error: entry.error
			}

		warning: (msg) ->
			warnings.push {
				message: msg
				query: entry.query
				params: entry.params
			}

	tooLate = -> throw new Error 'results must be reported synchronously'

	checks.forEach (check) -> check entry, result

	result.error = result.warning = tooLate

	return {errors, warnings}
