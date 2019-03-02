#! /usr/bin/env node

if( typeof module !== "undefined" )
{
  require( 'wTools' );

  var _ = _global_.wTools;

  _.include( 'wPathFundamentals' )
  _.include( 'wConsequence' )
  _.include( 'wFiles' )

  // var Chrome = require( './browser/Chrome.ss' );
  var Electron = require( './browser/electron/Electron.ss' );
  var portscanner = require( 'portscanner' );

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
    close electron child window when node process exits
    change focus of electron window when breakpoint is fired
*/

//

function init( o )
{
  var self = this;

  o = o || Object.create( null );

  _.assert( arguments.length === 0 | arguments.length === 1 );

  self.ready = new _.Consequence();
  self.nodes = [];
  self.state = Object.create( null );
  self.state.debug = 1;

}


/* Setup */

function setup()
{
  let self = this;

  self.ready.take( null );

  self.ready
  .thenKeep( () => self.setupIpc() )

  process.on( 'SIGINT', () =>
  {
    self.close();
  });
}

function setupIpc()
{
  let self = this;
  let con = new _.Consequence();

  ipc.config.id = 'nodewithdebug';
  ipc.config.retry= 1500;
  ipc.config.silent = true;

  ipc.serve( () =>
  {
    ipc.server.on( 'newNode', _.routineJoin( self, self.onNewNode ) );
    ipc.server.on( 'currentStateGet', _.routineJoin( self, self.onCurrentStateGet) );
    ipc.server.on( 'newElectron', _.routineJoin( self, self.onNewElectron ) );
    ipc.server.on( 'electronExit', _.routineJoin( self, self.onElectronExit ) );
    ipc.server.on( 'reload', _.routineJoin( self, self.onReload ) );
    con.take( true );
  });

  ipc.server.start();

  return con;
}

/* node */

function onNewNode( data,socket )
{
  let self = this;

  debugger

  let node = data.message;
  node.filePath = _.path.relative( process.cwd(), node.args[ 1 ] );
  node.args = node.args.slice( 2 );
  node.title = node.filePath + ' ' + node.args.join( ' ' );

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

  if( !self.nodes.length )
  {
    let electron = new Electron();
    self.electron = electron.launchElectron( [ node.url, node.title ] );
    self.electron.process.on( 'exit', () => { self.state.debug = 0 } )
  }
  else
  { 
    let message = { url : node.url, pid : node.id, args : node.args, title : node.title };
    ipc.server.broadcast( 'newNodeElectron', { id : ipc.config.id, message : message } );
  }

  self.nodes.push( node )
}

//

function onCurrentStateGet( data,socket )
{
  let self = this;
  ipc.server.emit( socket, 'currentState', { id : ipc.config.id, message : self.state } )
}

//

function onNewElectron( data, socket )
{
  let self = this;

  if( !self.electron.socket )
  self.electron.socket = socket;

  ipc.server.emit( socket, 'newElectronReady', { id : ipc.config.id, message : { ready : 1 } } )
}

//

function onElectronExit( data, socket )
{
  let self = this;
  self.close();
  process.exit();
}

function onReload( data, socket )
{
  let self = this;

  if( self.nodeProcess )
  self.nodeProcess.kill()

  if( self.electron )
  self.electron.process.kill();

  self.nodes = [];

  self.ready.finallyDeasyncKeep();

  self.runNode();
}

//

function runNode()
{
  let self = this;

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
    path : path,
    stdio : 'inherit',
    outputPiping : 0
  }

  let shell = _.shell( shellOptions );

  self.nodeProcess = shellOptions.process;

  // self.nodeProcess.on( 'exit', () =>
  // {
  //   console.log( 'main node exit' )
  // })

  self.ready.thenKeep( () => shell );

}

//

function close()
{
  let self = this;

  if( self.nodeProcess )
  self.nodeProcess.kill()

  if( self.electron )
  self.electron.process.kill()

  self.nodes = [];

  ipc.server.stop();

}

/* Launch */

function Launch()
{
  let node = new Self();
  node.setup();
  node.runNode();

  node.ready.got( () => node.close() );
}

// --
// relationships
// --

var Composes =
{
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
  electron : null,
  nodes : null,
  state : null
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

  onNewNode : onNewNode,
  onCurrentStateGet : onCurrentStateGet,
  onNewElectron : onNewElectron,
  onElectronExit : onElectronExit,
  onReload : onReload,

  close : close,

  // relationships

  // constructor : Self,
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