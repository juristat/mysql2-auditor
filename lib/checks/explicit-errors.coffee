module.exports = (entry, result) ->
	if entry.error?
		result.error(entry.error.message ? entry.error)
