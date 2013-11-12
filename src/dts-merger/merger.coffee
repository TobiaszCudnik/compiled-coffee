fs = require 'fs'

global.log ?= ->

mergeFile = (name) ->
	# check definitinon file
	# TODO async
	definition_file = name.replace(/\.ts$/, '.d.ts')
	if not fs.existsSync definition_file
		log "No definition d.ts file for '#{name}'"
		return

	# read files
	# TODO async
	source = fs.readFileSync name, 'utf8'
	definition = fs.readFileSync definition_file, 'utf8'

	merge source, definition

merge = (source, definition) ->

	config =
		indent: '(?:^|\\n)(?:\\s{4}|\\t)'

	regexps =
		CLASS: (name) ->
			name ?= '\\w+'
			new RegExp "class\\s(#{name})((?:\\n|.)+?)(?:\\n\\})", 'ig'
		METHOD: (name) ->
			name ?= '\\w+'
			new RegExp(
					"(#{config.indent})((?:(?:public|private)\\s)?(#{name})((?:\\n|[^=])+?))(?:\\s?\\{)", 'ig')
		ATTRIBUTE: (name) ->
			name ?= '\\w+'
			new RegExp(
					"(#{config.indent})((?:(?:public|private)\\s)?(#{name})((?:\\n|[^(])+?))(?:\\s?(=|;))", 'ig')
		MEMBER_DEF: (name) ->
			name ?= '\\w+'
			new RegExp(
					"#{config.indent}((?:public|private)?\\s?(#{name})((?:\\n|.)+?))(\\s?;)", 'i')

	# for each class in the source
	source = source.replace regexps.CLASS(), (match, name, body) ->
		log "Found class '#{name}"

		# match a corresponding class in the definiton file
		def = regexps.CLASS(name).exec definition
		return match if not def
		log "Found definition for class '#{name}"
		class_def = def[2]

		# for each method in the source class
		match = match.replace regexps.METHOD(), (match, indent, signature, name) ->
			log "Found method '#{name}'"
			# match a corresponding method in the class'es definiton
			def = regexps.MEMBER_DEF(name).exec class_def
			return match if not def
			log "Found definition for method '#{name}'"
			"#{indent}#{def[1]} {"

		# for each attribute in the source class
		match = match.replace regexps.ATTRIBUTE(), (match, indent, signature, name, space, suffix) ->
			log "Found attribute '#{name}'"
			# match a corresponding method in the class'es definiton
			def = regexps.MEMBER_DEF(name).exec class_def
			return match if not def
			log "Found definition for method '#{name}'"
			"#{indent}#{def[1]} #{suffix}"

	# TODO use body instead of match and return correct source

	source

module.exports = {merge, mergeFile}