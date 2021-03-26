#! /usr/bin/env node

var ipc, needle, portscanner;

if( typeof module !== 'undefined' )
{
  require( 'wTools' );

  const _ = _global_.wTools;

  _.include( 'wPathBasic' )
  _.include( 'wConsequence' )
  _.include( 'wFiles' )
  _.include( 'wCommandsAggregator' )

  ipc = require( 'node-ipc' );
  needle = require( 'needle' );
  portscanner = require( 'portscanner' );
}


const _ = _global_.wTools;
let Parent = null;
function NodeWithDebug( o )
{
  return _.workpiece.construct( Self, this, arguments );
}
const Self = NodeWithDebug;

Self.shortName = 'DebugNode';

const _global = _global_;
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
  ipc.config.silent = !Debug;

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

function onNewNode( data, socket )
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

  ipc.server.emit( socket, 'newNodeReady', { id : ipc.config.id, message : { ready : 1 } } )

  self.onInspectorServerReady( port )
  .deasync()
  .sync();

  needle.get( requestUrl, function( err, response )
  {
    if( err)
    throw _.err( err );

    if( response.statusCode !== 200 )
    throw _.err( 'Request failed. StatusCode:', response.statusCode );

    node.info = response.body[ 0 ];
    node.url = node.info.devtoolsFrontendUrl || node.info.devtoolsFrontendUrlCompat;
    node.url = _.strRemoveBegin( node.url, 'chrome-' );

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
      ipc.server.broadcast( 'newNodeElectron', { id : ipc.config.id, message } );
    }

    self.nodes.push( node );
    self.nodesMap[ node.id ] = node;
  })
}

//

function onCurrentStateGet( data, socket )
{
  let self = this;
  let pid = data.message.pid;
  let ppid = data.message.ppid;

  let parent = self.nodesMap[ ppid ];
  let parentIsActive = parent ? parent.isActive : true;
  ipc.server.emit( socket, 'currentState', { id : ipc.config.id, message : { state : self.state, parentIsActive } } )
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

function onInspectorServerReady( port )
{
  let attempts = 50;
  let errMsg = `Failed to check if nodejs debugger started at port: ${port} after ${attempts} attempts.`;

  return check();

  function check()
  {
    let con = new _.Consequence();

    if( !attempts )
    return con.error( errMsg );

    attempts -= 1;
    portscanner.checkPortStatus( port, '127.0.0.1', ( err, status ) =>
    {
      if( Debug )
      if( err )
      _.errLogOnce( err );
      con.take( status )
    });

    con.then( ( status ) =>
    {
      if( status === 'open' )
      return true;
      return _.time.out( 200, () => check() );
    })

    return con;
  }
}
//

function runNode()
{
  let self = this;

  /* prepare args */

  var execPath =
  [
    'node',
    '-r',
    _.path.nativize( _.path.join( __dirname, 'Preload.ss' ) ),
  ]

  let scriptArgs = self.args.slice( 1 );
  let scriptPath = scriptArgs[ 0 ];

  if( _.strHas( scriptPath, ' ' ) )
  scriptPath = _.strQuote( scriptPath )

  scriptArgs[ 0 ] = scriptPath;

  execPath.push.apply( execPath, scriptArgs );

  execPath = execPath.join( ' ' );

  let env = process.env;
  env.nodewithdebugId = ipc.config.id;
  env.PATH = process.env.PATH;

  var shellOptions =
  {
    mode : 'spawn',
    execPath,
    env,
    stdio : 'pipe',
    verbosity : Debug ? 2 : 0,
    outputPiping : Debug,
    applyingExitCode : 1,
    throwingExitCode : 0
  }

  /* run main node */

  let nodeCon = _.process.start( shellOptions );
  self.nodeCons.push( nodeCon );
  self.nodeProcess = shellOptions.pnd;
  // self.nodeProcess = shellOptions.process;

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

  shellOptions.pnd.stdout.pipe( process.stdout );
  // shellOptions.process.stdout.pipe( process.stdout );

  let rl = readline.createInterface
  ({
    input : shellOptions.pnd.stderr,
    // input : shellOptions.process.stderr,
  });

  rl.on( 'line', ( output ) =>
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

  var launcherPath = _.path.resolve( __dirname, './browser/electron/ElectronProcess.ss' );
  launcherPath = _.fileProvider.path.nativize( launcherPath );

  let env = process.env;
  env.nodewithdebugId = ipc.config.id;
  env.DISPLAY = process.env.DISPLAY;
  env.PATH = process.env.PATH;

  var o =
  {
    mode : 'spawn',
    execPath : appPath,
    args : [ '--no-sandbox', launcherPath ],
    stdio : 'pipe',
    env,
    ipc : 1,
    verbosity : 2,
    outputPiping : 1,
    applyingExitCode : 0,
    throwingExitCode : 0
  }

  self.electronCon = _.process.start( o );
  self.electronProcess = o.pnd;

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
  if( self.electronProcess.connected )
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
      if( err.errno === 'ESRCH' || err.code === 'ESRCH' )
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
  let appArgs = _.process.input({ keyValDelimeter : 0 });
  let ca = node._commandsMake();
  node.args = appArgs.scriptArgs;

  return ca.appArgsPerform({ appArgs });
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

    'help' : { e : _.routineJoin( node, node.commandHelp ), h : 'Get help.' },
    'run' : { e : _.routineJoin( node, node.commandRun ), h : 'Debug script.' },
  }

  let ca = node.ca = _.CommandsAggregator
  ({
    basePath : fileProvider.path.current(),
    commands,
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
    return new _.Consequence()
    .take( null )
    .andKeep( cons );
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

var Extension =
{

  init,

  checkScript,

  setup,
  setupIpc,
  runNode,
  runElectron,

  onNewNode,
  onCurrentStateGet,
  onNewElectron,
  onElectronExit,
  onElectronReady,
  onElectronChildClose,
  onDebuggerRestart,
  onInspectorServerReady,

  close,

  //

  _commandsMake,
  _commandHandleSyntaxError,

  commandHelp,
  commandRun,

  exec,

  // relationships

  Composes,
  Aggregates,
  Associates,
  Restricts,
  Statics

}

//

_.classDeclare
({
  cls : Self,
  parent : Parent,
  extend : Extension,
});

//
// export
// --

_global_.wTools[ Self.shortName ] = Self;

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;

