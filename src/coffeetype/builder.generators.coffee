Commands = require './commands'
suspend = require 'suspend'
go = suspend.resume
spawn = require('child_process').spawn
async = require 'async'
fs = require 'fs'
#spawn_ = spawn
#spawn = (args...) ->
#	console.log 'Executing: ', args
#	spawn_.apply null, args
path = require 'path'
EventEmitter = require('events').EventEmitter
require 'sugar'

class Builder extends EventEmitter
	clock: 0
	build_dirs_created: no
	source_dir: null
	output_dir: null
	sep: path.sep
	
	constructor: (@files, source_dir, output_dir) ->
		super
		
		@output_dir = path.resolve output_dir
		@source_dir = path.resolve source_dir
		
		@coffee_suffix = /\.coffee$/
		
	prepareDirs: suspend.async ->
		return if @build_dirs_created
		dirs = ['cs2ts', 'dist', 'typed', 'typescript']
		yield async.each dirs, (suspend.async (dir) =>
				dir_path = @output_dir + @sep + dir
				exists = yield fs.exists dir_path, suspend.resumeRaw()
				if not exists[0]
					yield fs.mkdir dir_path, go()
#					try yield fs.mkdir path, go()
#					catch e
#						throw e if e.type isnt 'EEXIST'
			), go()
		@build_dirs_created = yes

	build: suspend.async ->
		tick = ++@clock
		
		yield @prepareDirs go()
		
		cmd = Commands.cs2ts @files, @output_dir
		# Coffee to TypeScript
		@proc = spawn "#{__dirname}/../../#{cmd[0]}", cmd[1..-1], 
			cwd: @source_dir
		@proc.on 'error', console.log
		@proc.stderr.setEncoding 'utf8'
		@proc.stderr.on 'data', (err) -> console.log err
			
		yield @proc.on 'close', go()
		return @emit('aborted') if @clock isnt tick
		
		# Copy definitions
		yield async.map @files, (@copyDefinitionFiles.bind @), go()
		return @emit('aborted') if @clock isnt tick

		# Merge definitions
		@proc = spawn "#{__dirname}/../dts-merger.coffee", 
			['--output', "../typed"].include(@tsFiles()),
			cwd: "#{@output_dir}/cs2ts/"
		@proc.on 'error', console.log
		@proc.stderr.setEncoding 'utf8'
		@proc.stderr.on 'data', (err) -> console.log err
			
		yield @proc.on 'close', go()
		return @emit('aborted') if @clock isnt tick

		# Fix modules
		@proc = spawn "#{__dirname}/../commonjs-to-typescript.coffee", 
			['--output', "../typescript"].include(@tsFiles()),
			cwd: "#{@output_dir}/typed/"
		@proc.on 'error', console.log
		@proc.stderr.setEncoding 'utf8'
		@proc.stderr.on 'data', (err) -> console.log err
			
		yield @proc.on 'close', go()
		return @emit('aborted') if @clock isnt tick

		# Compile
		@proc = spawn "tsc", [
			"#{__dirname}/../../typings/ecma.d.ts", 
			"--module", "commonjs", 
			"--noLib"]
				.include(@tsFiles()),
			cwd: "#{@output_dir}/typescript/"
		@proc.on 'error', console.log
		@proc.stderr.setEncoding 'utf8'
		@proc.stderr.on 'data', (err) -> console.log err
			
		yield @proc.on 'close', go()
		return @emit('aborted') if @clock isnt tick
		# return if not yield null
	
		# move compiled to dist
		yield async.each @files, (@moveCompiledFiles.bind @), go()
		return @emit('aborted') if @clock isnt tick
		
		@proc = null
		
	tsFiles: -> 
		files = (file.replace @coffee_suffix, '.ts' for file in @files)
		
	moveCompiledFiles: (file, next) ->
		new_name = file.replace @coffee_suffix, '.js'
		fs.rename "#{@output_dir}/typescript/#{new_name}", 
			"#{@output_dir}/dist/#{new_name}", next
		
	copyDefinitionFiles: (file, next) ->
		# TODO create dirs in the output
		dts_file = file.replace @coffee_suffix, '.d.ts'
		destination = fs.createWriteStream "#{@output_dir}/cs2ts/#{dts_file}"
		destination.on 'close', next
		(fs.createReadStream @source_dir + @sep + dts_file).pipe destination

	close: ->
		@proc?.kill()
		
	clean: ->
		throw new Error 'not implemented'
		
	watch: ->
		for file in @files
			node = @source_dir + @sep + file
			fs.watchFile node, persistent: yes, interval: 500, =>
				console.log "\n#{'-'.repeat 20}\n\n"
				@proc?.kill()
				@build ->
		@build ->

module.exports = Builder