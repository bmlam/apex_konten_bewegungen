#! /usr/bin/python3 

from dbx import _dbx, _errorExit , g_maxDbxMsg, setDebug  
import os.path , re, sys , tempfile 

from collections import namedtuple
Script = namedtuple( "Script", [ "inpPath", "absPath" ] )
scripts = []

nestingLev = 0 
baseDir = ""
allLines = []


def parseCmdArgs() :
	import argparse

	parser = argparse.ArgumentParser()
	parser.add_argument( '-b','--baseDir', help='base location of scripts', required = True 	)
	parser.add_argument( '-m','--masterScriptPath', required= True	)
	# parser.add_argument( '-o','--outputFile', help='path of outputFile' )

	result= parser.parse_args()

	return result 

def checkResolvePath( inpPath ):
	global baseDir

	absPath = os.path.join( baseDir, inpPath )
	_dbx( absPath )

	if os.path.exists ( absPath ):
		script = Script( inpPath= inpPath, absPath= absPath)
	else:
		_errorExit( "script [%s] does not exist!" % (absPath))

	return script

def gotChildPath ( text ):
	#_dbx( text )
	z = re.match ( "^\s*(@|@@)(\s+)(.*)$" , text )
	if z:
		_dbx( len ( z.groups() ) )
		if len ( z.groups() ) == 3:
			scriptPath = z.group(3) 
			_dbx( scriptPath )

			return scriptPath.strip()

	z = re.match ( "^\s*(sta|star|start)(\s+)(.*)$" , text )
	if z:
		_dbx( len ( z.groups() ) )
		if len ( z.groups() ) == 3:
			scriptPath = z.group(3) 
			_dbx( scriptPath )

			return scriptPath.strip() 

def processScript( path ):
	global allLines, nestingLev, scripts 

	nestingLev += 1
	if nestingLev > 99:
		exit( "the program seems to have entered an infinite loop!")

	script = checkResolvePath( path ) # will error out if path is bad 
	scripts.append( script )

	lines =  open( script.absPath ).readlines()
	for line in lines:
		childPath = gotChildPath( line )
		if childPath:
			allLines.append ( "********** imbedding script " + childPath + "********** ")
			processScript( childPath )
		else:
			allLines.append( line.strip() )
	nestingLev -= 1
	allLines.append ( "********** end of expansion of script " + path + "********** ")

	scripts.pop ()
	
def main():
	global baseDir 

	argObj = parseCmdArgs()
	baseDir = argObj.baseDir 
	setDebug ( True )

	# following call is will process the master and children script recursively
	processScript ( argObj.masterScriptPath )
	if len( allLines ) > 0 :
		tempFile = tempfile.mktemp()
		print( "Writing output to %s" % (tempFile))
		open( tempFile, "w").write( "\n".join(allLines ) )
	else:
		print( "no content found in master script!")

		
if __name__ == "__main__":
		main()
