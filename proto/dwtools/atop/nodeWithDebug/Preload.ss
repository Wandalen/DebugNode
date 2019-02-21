(function _Preload_ss_() {

  'use strict';

  var inspector = require( 'inspector' );
  var ipc = require( 'node-ipc' );
  var deasync = require( 'deasync' );
  require( 'wFiles' );
  var _ = _global_.wTools;

  ipc.config.id = process.pid;
  ipc.config.retry = 1000;
  ipc.config.silent = true;

  let connectTo = deasyncEmptyCb( ipc, ipc.connectTo );
  connectTo( 'nodewithdebug' );
  let nodeWithDebug = ipc.of.nodewithdebug;
  let nodeWithDebugOn = deasyncEmptyCb( nodeWithDebug, nodeWithDebug.on );
  nodeWithDebugOn( 'connect' );

  if( !process.env.NODE_OPTIONS )
  process.env.NODE_OPTIONS = '';
  process.env.NODE_OPTIONS += ' --require ' + __filename;

  inspector.open( 0, undefined, false );

  let uri = _.uri.parse( inspector.url() );

  let port = Number( uri.port );

  var processInfo = { id : process.pid, debugPort : port, args : process.argv };

  inspector.close();

  nodeWithDebug.emit( 'newNode', { id :  process.pid, message : processInfo } )

  nodeWithDebugOn( 'newNodeReady' );

  inspector.open( port, undefined, true );

  ipc.disconnect( 'nodewithdebug' );

/**/

function deasyncEmptyCb( context, routine )
{
  return function ()
  {
      let ready = false
      let args = Array.prototype.slice.apply( arguments ).concat( cb );

      routine.apply( context, args );
      deasync.loopWhile( () => !ready )

      function cb()
      {
        ready = true
      }
  }
}

})();