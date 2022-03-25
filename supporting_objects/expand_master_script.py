#! /usr/bin/python3 

""" this script was built originally with these assumptions:
	* all child scripts are envoked like this
	  START path/to/child_script
	* path/to/child_script is a literal without ampersand as variable 
	* the current directory on which this script is run can read the content of ALL path/to/child_script 

	However for practical purpose the child script might be envoked like this 
	  START &&BASE_LOC/to/child_script 
	In this case this program needs to replace "&&BASE_LOC" with a literal that the user must provide, 
	so that the content of the child scripts can be read. Two additional pieces of information are needed:
	1. what is the name of the base location variable. In the example above it is "BASE_LOC"
	2. what does this variable need to be replaced with. Obviously, this must be the "common denominator" 
	   of all the child scripts
"""
from dbx import _dbx, _errorExit , g_maxDbxMsg, setDebug  
import os.path , re, sys , tempfile 

from collections import namedtuple
Script = namedtuple( "Script", [ "inpPath", "absPath" ] )
scripts = []

nestingLev = 0 
baseDir = ""
sqlplusVarName= None
allLines = []


def parseCmdArgs() :
	import argparse

	parser = argparse.ArgumentParser()
	parser.add_argument( '-b','--baseDir', help='base location of scripts', required = True 	)
	parser.add_argument( '-m','--masterScriptPath', required= True	)
	parser.add_argument( '-D','--pathCommonDenominator', help= "if master script contains a base location SQLPLUS variable, what is the variable name?" )
	parser.add_argument( '-V','--sqlplusVariableName', help= "if master script contains a base location SQLPLUS variable, what is the variable name?" )
	# parser.add_argument( '-o','--outputFile', help='path of outputFile' )

	result= parser.parse_args()
	if ( result.pathCommonDenominator and not result.sqlplusVariableName ) or ( not result.pathCommonDenominator and result.sqlplusVariableName ) :
		_errorExit( "-D and -V must be specified togehter!") 

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

def convertSqlplusVariable( scriptPath ):
	global sqlplusVarName, pathCommonDenom
	retVal = scriptPath
	# sqplus variable with two ampersands
	toReplace = "&&" + sqlplusVarName + os.path.sep 
	if scriptPath.startswith( toReplace ) :
		retVal = scriptPath.replace( toReplace, pathCommonDenom )
	else: 
		# sqlplus variable with one ampersand only 
		toReplace = "&" + sqlplusVarName + os.path.sep 
		if scriptPath.startswith( toReplace ) :
			retVal = scriptPath.replace( toReplace,  pathCommonDenom )
	return retVal

def gotChildPath ( text ):
	#_dbx( text )
	z = re.match ( "^\s*(@|@@)(\s+)(.*)$" , text )
	if z:
		_dbx( len ( z.groups() ) )
		if len ( z.groups() ) == 3:
			scriptPath = z.group(3) 
			_dbx( scriptPath )
			scriptPath = convertSqlplusVariable( scriptPath )

			return scriptPath.strip()
			_dbx( scriptPath )

	z = re.match ( "^\s*(sta|star|start)(\s+)(.*)$" , text )
	if z:
		_dbx( len ( z.groups() ) )
		if len ( z.groups() ) == 3:
			scriptPath = z.group(3) 
			_dbx( scriptPath )
			scriptPath = convertSqlplusVariable( scriptPath )

			return scriptPath.strip() 

def processScript( pathAsGiven ):
	global allLines, nestingLev, scripts 

	nestingLev += 1
	if nestingLev > 99:
		exit( "the program seems to have entered an infinite loop!")

	scriptPathComputed = checkResolvePath( pathAsGiven ) # will error out if path is bad 
	scripts.append( scriptPathComputed  )

	lines =  open( scriptPathComputed.absPath ).readlines()
	for line in lines:
		childPath = gotChildPath( line )
		if childPath:
			allLines.append ( "REM ********** imbedding script " + childPath + "********** ")
			processScript( childPath )
		else:
			allLines.append( line.rstrip() )
	nestingLev -= 1

	scripts.pop ()
	
def main():
	global baseDir , sqlplusVarName, pathCommonDenom

	argObj = parseCmdArgs()
	baseDir = argObj.baseDir 
	setDebug ( True )

	if argObj.sqlplusVariableName:
		sqlplusVarName = argObj.sqlplusVariableName 

	if argObj.pathCommonDenominator:
		pathCommonDenom = argObj.pathCommonDenominator 

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
