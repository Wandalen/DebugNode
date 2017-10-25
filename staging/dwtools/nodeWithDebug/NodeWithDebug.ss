#! /usr/bin/env node

if( typeof module !== "undefined" )
{
  require( 'wTools' );
  require( 'wPath' );
  require( 'wConsequence' );
  require( 'wFiles' );
  require( 'chromedriver' );

  var _ = wTools;

  var webdriver = require( 'selenium-webdriver' );
  var chrome = require( 'selenium-webdriver/chrome' );
}

//

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
  driver.get( url );
  var close = function()
  {
    this.driver.quit()
    .catch( (e) => null )
  }
  var browser =
  {
    driver  : driver,
    close : close
  }
  return browser;
}

//

function launch()
{
  var args = _.appArgs();

  if( !args.subject )
  throw _.err( 'Script file path is required!' );

  var scriptPath = _.pathJoin( _.pathCurrent(), args.subject );

  if( !_.fileProvider.fileStat( scriptPath ) )
  throw _.err( 'Provided file path does not exist! ', args.subject );

  var e = /^v(\d+).(\d+).(\d+)/.exec( process.version );

  if( !e )
  throw _.err( 'Cant parse node version', process.version );

  var nodeVersion =
  {
    major : Number.parseFloat( e[ 1 ] ),
    minor : Number.parseFloat( e[ 2 ] )
  }

  if( nodeVersion.major < 6 || nodeVersion.major === 6 && nodeVersion.minor < 3 )
  throw _.err( 'Incompatible node version: ', process.version, ', use 6.3.0 or higher!' );

  var flags = [];

  if( nodeVersion.major < 8 )
  flags.push( '--inspect', '--debug-brk' )
  else
  flags.push( '--inspect-brk' )

  flags.push( args.subject );

  if( args.map.args )
  flags.push( args.map.args );

  var shellOptions =
  {
    mode : 'spawn',
    path : 'node',
    args : flags,
    stdio : 'pipe',
  }

  var shell = _.shell( shellOptions );

  process.on( 'SIGINT', () => shellOptions.process.kill( 'SIGINT' ) );

  var debugUrlFinded = false;
  var onDebugReady = new wConsequence();

  shellOptions.process.stderr.on( 'data', ( data ) =>
  {
    data = data.toString();

    if( debugUrlFinded )
    return;

    var regexs = [ /chrome-devtools:\/\/.*/, /ws:\/\/.*/ ];
    for( var i = 0; i < regexs.length; i++  )
    {
      var regexp = regexs[ i ];
      if( regexp.test( data ) )
      {
        var url = data.match( regexp )[ 0 ];
        if( _.strBegins( url, 'ws://' ) )
        {
          var components =
          {
            origin : 'chrome-devtools://devtools/bundled/inspector.html',
            query : 'experiments=true&v8only=true'
          }
          components.query += '&ws=' + _.strRemoveBegin( url, 'ws://' );
          url = _.urlStr( components );
        }
        onDebugReady.give( url );
        debugUrlFinded = true;
        break;
      }
    }
  })

  onDebugReady.doThen( ( err, url ) =>
  {
    var browser = launchChrome( url );

    process.on( 'SIGINT', () => browser.close() );

    shell.doThen( () =>  browser.close() );

    return shell;
  })
}

//

launch();