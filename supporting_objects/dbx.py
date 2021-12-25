import inspect, os.path, sys , time 

g_dbxActive = True
g_dbxCntPrinted = 0
g_dbxCallCnt = 0 
g_maxDbxMsg = 1000 
g_suppressBefore = 0 
g_suppressAfter  = 999

g_modLineOccur = {}
g_modLineKeepalive = {}
g_modPathCommonPrefix = "/"

def _dbx ( text , maxPrint= 9 ):
	global g_dbxCntPrinted , g_dbxActive, g_maxDbxMsg, g_suppressBefore, g_suppressAfter, g_dbxCallCnt 
	g_dbxCallCnt += 1
	if g_dbxActive and g_dbxCntPrinted < g_maxDbxMsg and g_dbxCallCnt > g_suppressBefore and g_dbxCallCnt < g_suppressAfter :
		modLine = inspect.stack()[1][1] + ':' + str( inspect.stack()[1][2] )
		if modLine in g_modLineOccur.keys():
			g_modLineOccur[ modLine ] += 1 
		else:
			g_modLineOccur[ modLine ] = 1
			g_modLineKeepalive[ modLine ] = maxPrint		
		if g_modLineOccur[ modLine ] < maxPrint :
			print( 'dbx:%s: %s:%s - Ln%d: %s' % ( g_dbxCallCnt, inspect.stack()[1][1], inspect.stack()[1][3], inspect.stack()[1][2], text ) )
		if g_modLineOccur[ modLine ] == g_modLineKeepalive[ modLine ]  : # adaptive keepalive threshold reached
			print( 'dbx:%s KEEPALIVE %d: %s:%s - Ln%d: %s' % ( g_dbxCallCnt, g_modLineOccur[ modLine ], inspect.stack()[1][1], inspect.stack()[1][3], inspect.stack()[1][2], text ) )
			g_modLineKeepalive[ modLine ] *= 2
		g_dbxCntPrinted += 1

def _infoTs ( text , withTs = False ):
	global g_modPathCommonPrefix
	modPathFull = inspect.stack()[1][1] 
	modPathRel = os.path.relpath( modPathFull, g_modPathCommonPrefix )
	if withTs :
		print( '%s (Ln%d) %s' % ( time.strftime("%H:%M:%S"), inspect.stack()[1][2], text ) )
	else :
		print( '(%s:%d) %s' % ( modPathRel, inspect.stack()[1][2], text ) )

def _banner ( text , withTs = False ):
	global g_modPathCommonPrefix
	modPathFull = inspect.stack()[1][1] 
	modPathRel = os.path.relpath( modPathFull, g_modPathCommonPrefix )
	if withTs :
		print( '%s\n* %s (Ln%d) %s\n%s' % ( '*'*80, time.strftime("%H:%M:%S"), inspect.stack()[1][2], text, '*'*80 ) )
	else :
		print( '%s\n* (%s:%d) %s\n%s' % ( '*'*80, modPathRel, inspect.stack()[1][2],  text, '*'*80 ) )

def _errorExit ( text ):
	print( 'ERROR raised from %s - Ln%d: %s' % ( inspect.stack()[1][3], inspect.stack()[1][2], text ) )
	sys.exit(1)

def setDebug( flag, maxDbxMsg=999, suppressBefore=0, suppressAfter=99999 ):
	global g_dbxActive, g_maxDbxMsg, g_suppressBefore, g_suppressAfter
	g_dbxActive = flag
	g_maxDbxMsg = maxDbxMsg
	g_suppressBefore = suppressBefore
	g_suppressAfter = suppressAfter

def setModPathCommonPrexit( prefix ):
	global g_modPathCommonPrefix
	g_modPathCommonPrefix = prefix 

def printDbxStats():
	global g_dbxCntPrinted , g_dbxActive, g_maxDbxMsg, g_suppressBefore, g_suppressAfter, g_dbxCallCnt 
	print( "dbx stats: active=%s maxMsg=%s suppressBefore=%s, suppressAfter=%s, callCnt=%s" \
		% ( g_dbxActive, g_maxDbxMsg, g_suppressBefore, g_suppressAfter, g_dbxCallCnt ))

