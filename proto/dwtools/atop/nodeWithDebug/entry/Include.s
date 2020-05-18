( function _Include_s_( ) {

'use strict';

/**
 * Nodejs debugger based on Electron and Chrome DevTools.
  @module Tools/DebugNode
*/

if( typeof module !== 'undefined' )
{

  let _ = require( '../NodeWithDebug.ss' );
  module[ 'exports' ] = _global_.wTools;

  if( !module.parent )
  _global_.wTools.DebugNode.Exec();

}

})();
