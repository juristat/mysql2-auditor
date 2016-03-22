_ = require 'lodash'

module.exports = (entry, result) ->
	if entry.explanation?
		fs = findFilesort entry.explanation

		if fs.length > 0
			result.warn "Query uses #{fs.length} filesort(s)"

findFilesort = (thing) ->
	filesorts = []

	_.forIn thing, (val, key) ->
		if key is 'using_filesort' and val is true
			filesorts.push thing

		if _.isArray val
			val.forEach (elm) ->
				if _.isObject elm
					filesorts = filesorts.concat findFilesort elm

		if _.isObject val
			filesorts = filesorts.concat findFilesort val

	filesorts
