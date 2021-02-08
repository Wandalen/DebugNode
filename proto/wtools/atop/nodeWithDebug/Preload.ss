(function _Preload_ss_()
{

'use strict';

var inspector = require( 'inspector' );
var ipc = require( 'node-ipc' );
var deasync = require( 'wdeasync' );
var url = require('url');

ipc.config.id = process.pid;
ipc.config.retry = 1000;
ipc.config.silent = true;

let currentState, parentIsActive; // debugger window is not closed
let ppid = process.env.ppid;
let ipcHostId = process.env.nodewithdebugId;

let connectTo = deasyncEmptyCb( ipc, ipc.connectTo );
connectTo( ipcHostId );
let nodeWithDebug = ipc.of[ ipcHostId ];
let nodeWithDebugOn = deasyncEmptyCb( nodeWithDebug, nodeWithDebug.on );
nodeWithDebugOn( 'connect' );
nodeWithDebug.emit( 'currentStateGet', { id :  process.pid, message : { pid : process.pid, ppid } } )
nodeWithDebugOn( 'currentState' );

let preload = ' --require ' + __filename;

// skip node calls without script path, like node -e "..."
if( process.argv.length < 2 )
{
  ipc.disconnect( ipcHostId );
  return;
}

if( !parentIsActive || !currentState.debug )
{
  process.env.NODE_OPTIONS = strReplaceAll( process.env.NODE_OPTIONS, preload, '' );
  ipc.disconnect( ipcHostId );
  return;
}

if( !process.env.NODE_OPTIONS )
process.env.NODE_OPTIONS = '';
process.env.NODE_OPTIONS = strAppendOnce( process.env.NODE_OPTIONS, preload )

inspector.open( 0, undefined, false );

let uri = url.parse( inspector.url() );

let port = Number( uri.port );

var processInfo = { id : process.pid, ppid, debugPort : port, args : process.argv };

inspector.close();

nodeWithDebug.emit( 'newNode', { id :  process.pid, message : processInfo } )

nodeWithDebugOn( 'newNodeReady' );

inspector.open( port, undefined, true );

ipc.disconnect( ipcHostId );

process.env.ppid = process.pid;

// debugger //uncomment to debug preload script

/**/

function deasyncEmptyCb( context, routine )
{
  return function ()
  {
    let ready = false
    let args = Array.prototype.slice.apply( arguments ).concat( cb );
    let e = args[ 0 ];

    routine.apply( context, args );
    deasync.loopWhile( () => !ready )

    function cb( data )
    {
      if( e === 'currentState' )
      {
        currentState = data.message.state;
        parentIsActive = data.message.parentIsActive;
      }

      ready = true
    }
  }
}

function strReplaceAll( str, search, replacement)
{
  return str.replace(new RegExp( search, 'g' ), replacement );
};

function strAppendOnce( src, end )
{
  if( src.indexOf( end, src.length - end.length ) === -1 )
  return src + end;
  else
  return src;
}

})();
