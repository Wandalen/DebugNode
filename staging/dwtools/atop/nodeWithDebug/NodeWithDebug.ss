#! /usr/bin/env node

if( typeof module !== "undefined" )
{
  require( 'wTools' );
  require( 'wPath' );
  require( 'wConsequence' );
  require( 'wFiles' );

  // var Chrome = require( './browser/Chrome.ss' );
  var Electron = require( './browser/electron/Electron.ss' );
  var portscanner = require('portscanner')

  var _ = wTools;
}

//

var shell;
var debuggerPort;
var nodeVersion;

//

function getFreePort()
{
  var result = new wConsequence();

  portscanner.findAPortNotInUse( 1024, 65535, ( err, port ) =>
  {
    debuggerPort = port;
    result.give( err, port );
  });

  return result;
}

//

function launchDebugger( port )
{
  var e = /^v(\d+).(\d+).(\d+)/.exec( process.version );

  if( !e )
  throw _.err( 'Cant parse node version', process.version );

  nodeVersion =
  {
    major : Number.parseFloat( e[ 1 ] ),
    minor : Number.parseFloat( e[ 2 ] )
  }

  if( nodeVersion.major < 6 || nodeVersion.major === 6 && nodeVersion.minor < 3 )
  throw _.err( 'Incompatible node version: ', process.version, ', use 6.3.0 or higher!' );

  var flags = [];

  if( nodeVersion.major < 8 )
  flags.push( '--inspect=' + port,'--debug-brk' )
  else
  flags.push( '--inspect-brk=' + port )

  flags.push.apply( flags, process.argv.slice( 2 ) );

  var shellOptions =
  {
    mode : 'spawn',
    path : 'node',
    args : flags,
    stdio : 'pipe',
    outputPiping : 0
  }

  shell = _.shell( shellOptions );

  shellOptions.process.stdout.pipe( process.stdout );
  shellOptions.process.stderr.pipe( process.stderr );

  process.on( 'SIGINT', () => shellOptions.process.kill( 'SIGINT' ) );
}

//

function debuggerInfoGet( port )
{
  var request = require( 'request' );
  var requestUrl = 'http://localhost:' + port + '/json/list';

  var result = new wConsequence();

  request( requestUrl, ( err, res, data ) =>
  {
    if( err )
    return result.error( err );

    var info = JSON.parse( data )[ 0 ];
    result.give( info );
  })

  return result;
}

//

function launch()
{
  if( !process.argv[ 2 ] )
  {
    return helpGet();
  }

  var scriptPath = process.argv[ 2 ];
  scriptPath = _.pathJoin( _.pathCurrent(), scriptPath );

  if( !_.fileProvider.fileStat( scriptPath ) )
  throw _.err( 'Provided file path does not exist! ', process.argv[ 2 ] );

  return getFreePort()
  .ifNoErrorThen( () => launchDebugger( debuggerPort ) )
  .ifNoErrorThen( () => debuggerInfoGet( debuggerPort ) )
  .ifNoErrorThen( ( info ) =>
  {
    // var chrome = new Chrome();
    // var browser = chrome.launchChrome();
    // var onUrlLoaded = browser.gotoUrl( info.devtoolsFrontendUrl );

    // if( nodeVersion.major >= 8 )
    // {
    //   onUrlLoaded
    //   .doThen( () => browser.waitForPause() )
    //   .doThen( () => browser.unPause() );
    // }

    var electron = new Electron();
    var browser = electron.launchElectron( info.devtoolsFrontendUrl );

    process.on( 'SIGINT', () => browser.process.kill() );

    // shell.doThen( () =>  browser.close() );

    shell.doThen( browser.launched );

    return shell;
  })

  // var debugUrlFinded = false;
  // var onDebugReady = new wConsequence();

  // shellOptions.process.stderr.on( 'data', ( data ) =>
  // {
  //   data = data.toString();

  //   if( debugUrlFinded )
  //   return;

  //   var regexs = [ /chrome-devtools:\/\/.*/, /ws:\/\/.*/ ];
  //   for( var i = 0; i < regexs.length; i++  )
  //   {
  //     var regexp = regexs[ i ];
  //     if( regexp.test( data ) )
  //     {
  //       var url = data.match( regexp )[ 0 ];
  //       if( _.strBegins( url, 'ws://' ) )
  //       {
  //         var components =
  //         {
  //           origin : 'chrome-devtools://devtools/bundled/inspector.html',
  //           query : 'experiments=true&v8only=true'
  //         }
  //         components.query += '&ws=' + _.strRemoveBegin( url, 'ws://' );
  //         url = _.urlStr( components );
  //       }
  //       onDebugReady.give( url );
  //       debugUrlFinded = true;
  //       break;
  //     }
  //   }
  // })
}

//

function helpGet()
{
  var help =
  {
    Usage :
    [
      'nodewithdebug [ path ] [ args ]',
      'NodeWithDebug expects path to script file and its arguments( optional ).'
    ],
    Examples :
    [
      'nodewithdebug sample/Sample.js',
      'nodewithdebug sample/Sample.js arg1 arg2 arg3',
    ]
  }

  var strOptions =
  {
    levels : 3,
    wrap : 0,
    stringWrapper : '',
    multiline : 1
  };

  var help = _.toStr( help, strOptions );

  logger.log( help );

  return help;
}

//

launch();