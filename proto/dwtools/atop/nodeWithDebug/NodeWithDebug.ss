#! /usr/bin/env node

if( typeof module !== "undefined" )
{
  require( 'wTools' );

  var _ = _global_.wTools;

  _.include( 'wPathBasic' )
  _.include( 'wConsequence' )
  _.include( 'wFiles' )
  _.include( 'wCommandsAggregator' )

  var ipc = require('node-ipc');
  var request = require( 'request' );
}


var Parent = null;
var Self = function NodeWithDebug( o )
{
  return _.workpiece.construct( Self, this, arguments );
}

Self.nameShort = 'DebugNode';

let _global = _global_;
let Debug = false;

/*

todo:

  + resume execution of child nodes( remove preload script ) when main electron window is closed
  + close electron child window when node process exits
  + change focus of electron window when breakpoint is fired
*/

//

function init( o )
{
  var self = this;

  o = o || Object.create( null );

  _.assert( arguments.length === 0 | arguments.length === 1 );
  
  self.ready = new _.Consequence();
  self.nodes = [];
  self.nodesMap = Object.create( null );
  self.nodeCons = [];
  self.state = Object.create( null );
  self.state.debug = 1;
  self.electronReady = new _.Consequence();
  self.closed = false;
  self.logger = new _.Logger({ output : _global.logger, name : Self.nameShort, verbosity : self.verbosity });
  
  _.workpiece.initFields( self );

}

function checkScript()
{ 
  let node = this;
  let scriptPath = node.args[ 1 ];
  
  if( !_.strDefined( scriptPath ) )
  throw _.errBrief( `Debugger expects path to script file.` )
  
  scriptPath = _.path.resolve( scriptPath );
  
  if( !_.fileProvider.fileExists( scriptPath ) )
  throw _.errBrief( `Provided script path:${ _.strQuote( _.path.nativize( scriptPath ) ) } doesn't exist.` )
  
  if( !_.fileProvider.isTerminal( scriptPath ) )
  throw _.errBrief( `Provided script:${ _.strQuote( _.path.nativize( scriptPath ) ) } is not a terminal file.` )
  
  return null;
}


/* Setup */

function setup()
{
  let self = this;

  process.once( 'SIGINT', () =>
  {
    if( self.verbosity )
    console.log( 'SIGINT' );
    self.close();
  });

  return self.setupIpc();
}

function setupIpc()
{
  let self = this;
  let con = new _.Consequence();

  ipc.config.id = 'nodewithdebug.' + process.pid;
  ipc.config.retry= 1500;
  ipc.config.silent = true;

  ipc.serve( () =>
  { 
    ipc.server.on( 'newNode', _.routineJoin( self, self.onNewNode ) );
    ipc.server.on( 'currentStateGet', _.routineJoin( self, self.onCurrentStateGet) );
    ipc.server.on( 'electronReady', _.routineJoin( self, self.onElectronReady ) );
    ipc.server.on( 'electronChildClosed', _.routineJoin( self, self.onElectronChildClose ) );
    ipc.server.on( 'debuggerRestart', _.routineJoin( self, self.onDebuggerRestart ) );
    
    
    con.take( true );
  });

  ipc.server.start();

  return con;
}

/* node */

function onNewNode( data,socket )
{
  let self = this;

  // debugger

  let node = data.message;
  // node.filePath = _.path.relative( process.cwd(), node.args[ 1 ] );
  node.filePath = node.args[ 1 ];
  node.args = node.args.slice( 2 );
  node.title = node.filePath;

  if( node.args.length )
  node.title += ' ' + node.args.join( ' ' );

  var port = node.debugPort;
  var requestUrl = 'http://localhost:' + port + '/json/list';

  var con = new wConsequence();

  ipc.server.emit( socket, 'newNodeReady', { id : ipc.config.id, message : { ready : 1 } } )

  request( requestUrl, ( err, res, data ) =>
  {
    if( err )
    return con.error( err );

    var info = JSON.parse( data )[ 0 ];
    con.take( info );
  })

  node.info = con.deasyncWait().sync();

  node.url = node.info.devtoolsFrontendUrl || node.info.devtoolsFrontendUrlCompat;

  let message =
  {
    url : node.url,
    pid : node.id,
    ppid : node.ppid,
    args : node.args,
    title : node.title,
    isMaster : !self.nodes.length
  };

  if( self.verbosity )
  console.log( 'newNode:', message )
  
  let parent;
  if( node.ppid )
  parent = self.nodesMap[ node.ppid ];
  let skip = parent && !parent.isActive; // don't connect electron to child if parent is closed;
  
  if( !skip )
  { 
    node.isActive = true;
    ipc.server.broadcast( 'newNodeElectron', { id : ipc.config.id, message : message } );
  }

  self.nodes.push( node );
  self.nodesMap[ node.id ] = node;
}

//

function onCurrentStateGet( data,socket )
{
  let self = this;
  let pid = data.message.pid;
  let ppid = data.message.ppid;
  
  let parent = self.nodesMap[ ppid ];
  let parentIsActive = parent ? parent.isActive : true;
  ipc.server.emit( socket, 'currentState', { id : ipc.config.id, message : { state : self.state, parentIsActive : parentIsActive } } )
}

//

function onNewElectron( data, socket )
{
  let self = this;

  if( !self.electronSocket )
  self.electronSocket = socket;

  ipc.server.emit( socket, 'newElectronReady', { id : ipc.config.id, message : { ready : 1 } } )
}

//

function onElectronExit( data, socket )
{
  let self = this;
  self.close();
  process.exit();
}

//

function onElectronChildClose( data, socket )
{
  let self = this;
  let pid = data.message.pid;
  _.assert( _.definedIs( pid ) );
  let node = self.nodesMap[ pid ];
  if( node )
  node.isActive = false;
}

function onDebuggerRestart( data, socket )
{
  let self = this;
  
  if( self.nodeProcess )
  self.nodeProcess.kill();

  self.nodes = [];
  self.nodesMap = Object.create( null );
  
  self.runNode();
}

//

function runNode()
{
  let self = this;

  /* prepare args */

  var path =
  [
    'node',
    '-r',
    _.path.nativize( _.path.join( __dirname, 'Preload.ss' ) ),
  ]
  
  path.push.apply( path, self.args.slice( 1 ) );
  
  path = path.join( ' ' );

  var shellOptions =
  {
    mode : 'spawn',
    execPath : path,
    env : { nodewithdebugId : ipc.config.id, PATH: process.env.PATH },
    stdio : 'pipe',
    verbosity : Debug ? 2 : 0,
    outputPiping : Debug,
    applyingExitCode : 1,
    throwingExitCode : 0
  }

  /* run main node */

  let nodeCon = _.process.start( shellOptions );
  self.nodeCons.push( nodeCon );
  self.nodeProcess = shellOptions.process;
  
  var readline = require('readline');

  /* filter stderr */

  const stdErrFilter =
  [
    'Debugger listening',
    'Waiting for the debugger',
    'Debugger attached',
    'For help, see:',
    'https://nodejs.org/en/docs/inspector'
  ];
  
  shellOptions.process.stdout.pipe( process.stdout );
  
  let rl = readline.createInterface
  ({
    input: shellOptions.process.stderr,
  });
  
  rl.on( 'line', output =>
  {
    for( var f in stdErrFilter )
    if( _.strHas( output, stdErrFilter[ f ] ) )
    return;
    
    output = _.color.strFormat( output, 'pipe.negative' );
    
    logger.error( output );
  })

  return true;
}

//

function runElectron()
{
  let self = this;

  var appPath = require( 'electron' );

  var launcherPath  = _.path.resolve( __dirname, './browser/electron/ElectronProcess.ss' );
  launcherPath  = _.fileProvider.path.nativize( launcherPath );

  var o =
  {
    mode : 'spawn',
    execPath : appPath,
    args : [ '--no-sandbox', launcherPath ],
    stdio : 'pipe',
    env : { nodewithdebugId : ipc.config.id, 'DISPLAY': process.env.DISPLAY },
    ipc : 1,
    verbosity : Debug ? 2 : 0,
    outputPiping : Debug,
    applyingExitCode : 0,
    throwingExitCode : 0
  }

  self.electronCon = _.process.start( o );
  self.electronProcess = o.process;

  self.electronProcess.once( 'exit', () => { self.state.debug = 0; })
  self.electronProcess.once( 'SIGINT', () => { self.state.debug = 0; })

  return self.electronReady;
}

//

function onElectronReady()
{
  let self = this;
  self.electronReady.take( null );
}

//

function close()
{
  let self = this;

  if( self.closed )
  return;

  self.closed = true;

  if( self.verbosity )
  console.log( 'closing' )

  if( self.electronProcess )
  self.electronProcess.send({ exit : 1 } );

  if( self.nodeProcess )
  self.nodeProcess.kill();
  
  _.each( self.nodes, ( node ) => 
  { 
    try
    {
      process.kill( node.id, 'SIGKILL' );
    }
    catch( err )
    { 
      if( err.errno === 'ESRCH' )
      return;
      
      throw err;
    }
  });

  self.nodes = [];
  
  if( ipc.server.stop )
  ipc.server.stop();

  /**/
}

/* Launch */

function Exec()
{
  let node = new Self();
  return node.exec();
}

function exec()
{
  let node = this;
  let appArgs = _.process.args({ keyValDelimeter : 0 });
  let ca = node._commandsMake();
  node.args = appArgs.scriptArgs;

  return ca.appArgsPerform({ appArgs : appArgs });
}

//

function _commandsMake()
{
  let node = this;
  let fileProvider = _.fileProvider;

  _.assert( _.instanceIs( node ) );
  _.assert( arguments.length === 0 );

  let commands =
  {

    'help' :                    { e : _.routineJoin( node, node.commandHelp ),                        h : 'Get help.' },
    'run' :                     { e : _.routineJoin( node, node.commandRun ),                         h : 'Debug script.' },
  }

  let ca = node.ca = _.CommandsAggregator
  ({
    basePath : fileProvider.path.current(),
    commands : commands,
    commandPrefix : 'node ',
    logger : node.logger,
    onSyntaxError : ( o ) => node._commandHandleSyntaxError( o ),
  })

  _.assert( ca.logger === node.logger );
  _.assert( ca.verbosity === node.verbosity );

  ca.form();

  return ca;
}

//

function _commandHandleSyntaxError( o )
{
  let node = this;
  let ca = node.ca;
  node.args.unshift( '.run' );
  return ca.commandPerform({ command : '.run' });
}

//

function commandHelp( e )
{
  let node = this;
  let ca = e.ca;
  let logger = node.logger;

  logger.log( 'Known commands' );

  ca._commandHelp( e );
  
  logger.log( '\nHow to use debugger:' );
  logger.log( 'debugnode [script path] [arguments]' );
  logger.log( 'debugnode .run [script path] [arguments]' );
}

//

function commandRun( e )
{
  let node = this;
  let ca = e.ca;
  
  let ready = node.ready;

  ready.take( null )
  ready.then( () => node.checkScript() );
  ready.then( () => node.setup() );
  ready.then( () => node.runElectron() );
  ready.then( () => node.runNode() );

  ready.then( () => AndKeep([ node.electronCon ]) )
  ready.then( () => AndKeep( node.nodeCons ) );

  ready.finally( ( err, got ) =>
  {
    if( node.verbosity )
    console.log( 'terminated/finished' );
    node.state.debug = 0;

    if( err )
    _.errLogOnce( err );
    
    if( node.verbosity )
    console.log( 'exiting...' );
    
    node.close();
    
    return null;
  });
  
  return ready;

  /*  */

  function AndKeep( cons )
  {
    return new _.Consequence().take( null ).andKeep( cons );
  }
}

// --
// relationships
// --

var Composes =
{
  verbosity : 0
}

var Aggregates =
{
}

var Associates =
{
  logger : null
}

var Restricts =
{
  ready : null,
  nodeProcess : null,
  nodeCons : null,
  electronProcess : null,
  electronCon : null,
  electronSocket : null,
  electronReady : null,
  nodes : null,
  nodesMap : null,
  state : null,
  closed : null,
  ca : null,
  args : null
}

var Statics =
{
  Exec
}

// --
// prototype
// --

var Extend =
{

  init : init,
  
  checkScript,

  setup : setup,
  setupIpc : setupIpc,
  runNode : runNode,
  runElectron : runElectron,

  onNewNode : onNewNode,
  onCurrentStateGet : onCurrentStateGet,
  onNewElectron : onNewElectron,
  onElectronExit : onElectronExit,
  onElectronReady : onElectronReady,
  onElectronChildClose : onElectronChildClose,
  onDebuggerRestart : onDebuggerRestart,

  close : close,
  
  //
  
  _commandsMake,
  _commandHandleSyntaxError,
  
  commandHelp,
  commandRun,
  
  exec,

  // relationships

  Composes : Composes,
  Aggregates : Aggregates,
  Associates : Associates,
  Restricts : Restricts,
  Statics : Statics,

}

//

_.classDeclare
({
  cls : Self,
  parent : Parent,
  extend : Extend,
});

if( !module.parent )
Self.Exec();

//
// export
// --

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;