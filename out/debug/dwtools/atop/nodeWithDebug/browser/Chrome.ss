(function _Chrome_ss_() {

'use strict';

if( typeof module !== 'undefined' )
{
  require( 'chromedriver' );
}

//

/**
 * @class Chrome
 */

var _ = wTools;
var webdriver = require( 'selenium-webdriver' );
var chrome = require( 'selenium-webdriver/chrome' );

var Parent = null;
var Self = function Chrome( o )
{
  if( !( this instanceof Self ) )
  if( o instanceof Self )
  return o;
  else
  return new( _.routineJoin( Self, Self, arguments ) );
  return Self.prototype.init.apply( this,arguments );
}

Self.nameShort = 'Chrome';

//

function init( o )
{
  var self = this;

  _.assert( arguments.length === 0 | arguments.length === 1 );

}

function launchChrome( url )
{

  var userPrefs =
  { 'devtools' :
    {
    'preferences' : { 'inlineVariableValues' : 'false' }
    }
  }

  var options = new chrome.Options();
  options.setUserPreferences( userPrefs )
  var driver = new webdriver.Builder()
  .forBrowser('chrome')
  .setChromeOptions( options )
  .build();

  var close = function()
  {
    this.driver.quit()
    .catch( (e) => null )
  }

  var gotoUrl = function( url )
  {
    var p = this.driver.get( url );
    return wConsequence.From( p );
  }

  var waitForPause = function()
  {
    var condition = new webdriver.Condition( 'Not paused', ( driver ) =>
    {
      var script =
      `
      try{ return window.Sources.SourcesPanel.instance()._paused; }
      catch( err ){}
      `
      return driver.executeScript( script );
    })

    var p = this.driver.wait( condition, 5000, 'Pause condition timed out!.'  );
    return wConsequence.From( p );
  }

  var unPause = function()
  {
    var script = `return window.Sources.SourcesPanel.instance()._togglePause();`
    var p = this.driver.executeScript( script );
    return wConsequence.From( p );
  }

  var browser =
  {
    driver  : driver,
    close : close,
    gotoUrl : gotoUrl,
    waitForPause : waitForPause,
    unPause : unPause
  }
  return browser;
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

  launchChrome : launchChrome,

  // relationships

  constructor : Self,
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
