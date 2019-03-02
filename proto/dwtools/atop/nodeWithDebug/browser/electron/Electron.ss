(function _Electron_ss_() {

'use strict';

if( typeof module !== 'undefined' )
{
}

//

/**
 * @class Electron
 */

var _ = _global_.wTools;

var Parent = null;
var Self = function Electron( o )
{
  if( !( this instanceof Self ) )
  if( o instanceof Self )
  return o;
  else
  return new( _.routineJoin( Self, Self, arguments ) );
  return Self.prototype.init.apply( this,arguments );
}

Self.nameShort = 'Electron';

//

function init( o )
{
  var self = this;

  _.assert( arguments.length === 0 | arguments.length === 1 );

}

function launchElectron( args )
{

  var appPath = require( 'electron' );

  var launcherPath  = _.path.resolve( __dirname, './ElectronProcess.ss' );
  launcherPath  = _.fileProvider.path.nativize( launcherPath );

  var flags =
  [
    launcherPath,
  ];

  _.arrayAppendArray( flags, args );

  var o =
  {
    mode : 'spawn',
    path : appPath,
    args : flags,
    stdio : 'inherit',
    outputPiping : 0,
  }

  o.launched = _.shell( o );
  return o;
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
}

var Statics =
{
}

// --
// prototype
// --

var Proto =
{

  init : init,

  launchElectron : launchElectron,

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

//
// export
// --

if( typeof module !== 'undefined' && module !== null )
module[ 'exports' ] = Self;

})();
