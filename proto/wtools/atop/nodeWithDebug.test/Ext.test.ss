( function _External_test_s_( )
{

'use strict';

if( typeof module !== 'undefined' )
{
  const _ = require( '../../Tools.s' );

  _.include( 'wTesting' );
  _.include( 'wProcess' );
  _.include( 'wFiles' );
}

const _global = _global_;
const _ = _global_.wTools;

// --
//
// --

function onSuiteBegin()
{
  let self = this;
  self.suiteTempPath = _.path.tempOpen( _.path.join( __dirname, '../..' ), 'DebugNode' );
  self.assetsOriginalPath = _.path.join( __dirname, '_asset' );
  self.toolsPath = _.path.nativize( _.path.join( _.path.normalize( __dirname ), '../Tools.s' ) );
  self.appJsPath = _.path.join( __dirname, '../nodeWithDebug/entry/Exec' );
}

function onSuiteEnd()
{
  let self = this;
  _.assert( _.strHas( self.suiteTempPath, 'DebugNode' ) )
  _.path.tempClose( self.suiteTempPath );
}

// --
//
// --

//

function installLocally( test )
{
  let self = this;
  let a = test.assetFor( 'install-locally' );

  a.reflect();
  a.shell( 'npm i' )
  .then( ( got ) =>
  {
    test.identical( got.exitCode, 0 );
    return null;
  })

  return a.ready;

}

installLocally.description =
`
Install utility locally.
`

//

function run( test )
{
  let self = this;
  let a = test.assetFor( 'run' );

  a.reflect();
  a.appStartNonThrowing({ args : [ 'Index.js', 'arg1', 'arg2' ] })
  .then( ( got ) =>
  {
    test.identical( got.exitCode, 0 );
    test.true( _.strHas( got.output, `[ 'arg1', 'arg2' ]` ) )
    return null;
  })

  return a.ready;
}

//

function env( test )
{
  let self = this;
  let a = test.assetFor( 'env' );

  a.reflect();
  a.appStartNonThrowing({ args : [ 'Index.js' ] })
  .then( ( got ) =>
  {
    test.identical( got.exitCode, 0 );
    test.true( _.strHas( got.output, `Index.js executed` ) )
    test.true( _.strHas( got.output, `Child.js executed` ) )
    return null;
  })

  return a.ready;
}

env.timeOut = 30000;

//

// function returnExitCode()
// {
//   let code = Number.parseInt( process.argv[ 2 ] );
//   process.exit( code );
// }

// function trivial( t )
// {
//   let self = this;

//   let provider = new _.FileProvider.Http();

//   let ready = new _.Consequence().take( null );

//   ready.then( () => provider.fileRead({ filePath : 'http://localhost:8315/json/list', sync : 0 }) )

//   ready.then( ( got ) =>
//   {
//     let read = JSON.parse( got )[ 0 ];
//     return read;
//   })

//   ready.then( ( got ) =>
//   {
//     const options =
//     {
//       tab: got.webSocketDebuggerUrl
//     };

//     let con = new _.Consequence();

//     CDP(options, ( client ) =>
//     {
//       console.log( 'Connected!' );

//       var Network = client.Network;
//       var Page = client.Page;
//       var Runtime = client.Runtime;

//       con.take( null );

//       con.then( _.Consequence.From( Network.enable() ) )
//       con.then( _.Consequence.From( Page.enable() ) )
//       con.then( _.Consequence.From( Runtime.evaluate({ expression: 'window.close()' }) ) )
//       con.then( () => client.close() )
//     })
//     .on('error', (err) =>
//     {
//       con.error( err )
//     });

//     return con;
//   })

//   return ready;
// }

//

// function exitCode( test )
// {
//   let self = this;

//   let scriptPath = _.path.nativize( _.path.join( self.tempDir, test.name, 'Script.js' ) );

//   let ready = new _.Consequence().take( null );

//   ready.then( () =>
//   {
//     _.fileProvider.fileWrite( scriptPath, returnExitCode.toString() + '\nreturnExitCode();');
//     return null;
//   })

//   /* */

//   .then( () =>
//   {
//     test.case = 'bad code';
//     return _.process.start
//     ({
//       mode : 'spawn',
//       execPath : 'node',
//       args : [ DebugNodePath, scriptPath, 1 ],
//       verbosity : 1,
//       outputPiping : 1,
//       applyingExitCode : 0,
//       throwingExitCode : 0
//     })
//   })
//   .then( ( got ) =>
//   {
//     test.identical( got.exitCode, 1 );
//     return null;
//   })

//   /* */

//   .then( () =>
//   {
//     test.case = 'good code';
//     return _.process.start
//     ({
//       mode : 'spawn',
//       execPath : 'node',
//       args : [ DebugNodePath, scriptPath, 0 ],
//       verbosity : 1,
//       outputPiping : 1,
//       applyingExitCode : 0,
//       throwingExitCode : 0
//     })
//   })
//   .then( ( got ) =>
//   {
//     test.identical( got.exitCode, 0 );
//     return null;
//   })

//   return ready;
// }

//

const Proto =
{

  name : 'Tools/atop/DebugNode',
  silencing : 1,

  onSuiteBegin,
  onSuiteEnd,
  routineTimeOut : 300000,

  context :
  {
    suiteTempPath : null,
    assetsOriginalPath : null,
    appJsPath : null,
    toolsPath : null,
  },

  tests :
  {
    installLocally,
    run,
    env
  }

}

//

const Self = wTestSuite( Proto );
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self.name );

})();
