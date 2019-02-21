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

//

function init( o )
{
  var self = this;

  o = o || Object.create( null );

  _.assert( arguments.length === 0 | arguments.length === 1 );

  self.ready = new _.Consequence();
  self.nodes = [];

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

  let url = node.info.devtoolsFrontendUrl || node.info.devtoolsFrontendUrlCompat;

  if( !self.nodes.length )
  {
    let electron = new Electron();
    self.electron = electron.launchElectron( url );
  }
  else
  {
    ipc.server.broadcast( 'newNodeElectron', { id : ipc.config.id, message : { url : url } } );
  }

  self.nodes.push( node )
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
    process.argv[ 2 ]
  ]
  .join( ' ' );

  var shellOptions =
  {
    mode : 'spawn',
    path : path,
    stdio : 'inherit',
    outputPiping : 0
  }

  let shell = _.shell( shellOptions );

  self.nodeProcess = shellOptions.process;

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
  nodes : null
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