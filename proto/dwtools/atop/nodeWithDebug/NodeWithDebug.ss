#! /usr/bin/env node

if( typeof module !== "undefined" )
{
  require( 'wTools' );

  var _ = _global_.wTools;

  _.include( 'wPathBasic' )
  _.include( 'wConsequence' )
  _.include( 'wFiles' )

  var ipc = require('node-ipc');
  var request = require( 'request' );
}

var Parent = null;
var Self = function NodeWithDebug( o )
{
  if( !( this instanceof Self ) )
  if( o instanceof Self )
  return o;
  else
  return new( _.routineJoin( Self, Self, arguments ) );
  return Self.prototype.init.apply( this,arguments );
}

Self.nameShort = 'DebugNode';

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
  self.verbosity = 0;

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

  node.info = con.finallyDeasyncKeep();

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

  path.push.apply( path, process.argv.slice( 2 ) );
  path = path.join( ' ' );

  var shellOptions =
  {
    mode : 'spawn',
    execPath : path,
    env : { nodewithdebugId : ipc.config.id, PATH: process.env.PATH },
    stdio : 'pipe',
    verbosity : 0,
    outputPiping : 0,
    applyingExitCode : 1,
    throwingExitCode : 0
  }

  /* run main node */

  let nodeCon = _.shell( shellOptions );
  self.nodeCons.push( nodeCon );
  self.nodeProcess = shellOptions.process;

  /* filter stderr */

  const stdErrFilter =
  [
    'Debugger listening',
    'Waiting for the debugger',
    'Debugger attached.',
    'For help, see:'
  ];
  
  shellOptions.process.stdout.pipe( process.stdout );
  shellOptions.process.stderr.on( 'data', ( data ) =>
  {
    if( _.bufferAnyIs( data ) )
    data = _.bufferToStr( data );
    
    for( var f in stdErrFilter )
    if( _.strHas( data, stdErrFilter[ f ] ) )
    return;

    process.stderr.write( data );
  });


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
    verbosity : 0,
    outputPiping : 0,
    applyingExitCode : 0,
    throwingExitCode : 0
  }

  self.electronCon = _.shell( o );
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

  ipc.server.stop();

  /**/
}

/* Launch */

function Launch()
{
  let node = new Self();
  let ready = node.ready;

  ready.take( null )
  ready.then( () => node.setup() );
  ready.then( () => node.runElectron() );
  ready.then( () => node.runNode() );

  ready.then( () => AndKeep([ node.electronCon ]) )
  ready.then( () => AndKeep( node.nodeCons ) );

  ready.give( ( err, got ) =>
  {
    if( node.verbosity )
    console.log( 'terminated/finished' );
    node.state.debug = 0;

    if( err )
    _.errLogOnce( err );
    
    if( node.verbosity )
    console.log( 'exiting...' );
    
    node.close();
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
  verbosity : 1
}

var Aggregates =
{
}

var Associates =
{
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
  closed : null
}

var Statics =
{
  Launch : Launch
}

// --
// prototype
// --

var Proto =
{

  init : init,

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
  extend : Proto,
});

Launch();

//
// export
// --

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;