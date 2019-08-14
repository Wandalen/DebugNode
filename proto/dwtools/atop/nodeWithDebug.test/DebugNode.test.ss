( function _DebugNode_test_s_( ) {

  'use strict';
  
  if( typeof module !== 'undefined' )
  {
    let _ = require( '../../Tools.s' );
  
    _.include( 'wTesting' );
    _.include( 'wAppBasic' );
    _.include( 'wFiles' );
    
    // var DebugNode = require( '../nodeWithDebug/NodeWithDebug.ss' );
    var DebugNodePath = require.resolve( '../nodeWithDebug/NodeWithDebug.ss' );
  }
  
  var _global = _global_;
  var _ = _global_.wTools;
  
  // --
  //
  // --
  
  function onSuiteBegin()
  {
    let self = this;
  
    self.tempDir = _.path.dirTempOpen( _.path.join( __dirname, '../..'  ), 'DebugNode' );
  }
  
  function onSuiteEnd()
  {
    // let self = this;
    // _.assert( _.strHas( self.tempDir, '/dwtools/tmp.tmp' ) )
    // _.fileProvider.filesDelete( self.tempDir );
  }
  
  // --
  //
  // --
  
  function returnExitCode()
  { 
    let code = Number.parseInt( process.argv[ 2 ] );
    process.exit( code );
  }
  
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
  
  function exitCode( test )
  {
    let self = this;
    
    let scriptPath = _.path.nativize( _.path.join( self.tempDir, test.name, 'Script.js' ) );
    
    let ready = new _.Consequence().take( null );
    
    ready.then( () => 
    {
      _.fileProvider.fileWrite( scriptPath, returnExitCode.toString() + '\nreturnExitCode();');
      return null; 
    })
    
    /* */
    
    .then( () => 
    {
      test.case = 'bad code';
      return _.shell
      ({ 
        mode : 'spawn',
        execPath : 'node',
        args : [ DebugNodePath, scriptPath, 1 ], 
        verbosity : 1,
        outputPiping : 1,
        applyingExitCode : 0,
        throwingExitCode : 0
      })
    })
    .then( ( got ) => 
    {
      test.identical( got.exitCode, 1 );
      return null; 
    })
    
    /* */
    
    .then( () => 
    {
      test.case = 'good code';
      return _.shell
      ({ 
        mode : 'spawn',
        execPath : 'node',
        args : [ DebugNodePath, scriptPath, 0 ], 
        verbosity : 1,
        outputPiping : 1,
        applyingExitCode : 0,
        throwingExitCode : 0
      })
    })
    .then( ( got ) => 
    {
      test.identical( got.exitCode, 0 );
      return null; 
    })
    
    return ready;
  }
  
  //
  
  var Self =
  {
  
    name : 'Tools/atop/DebugNode',
    silencing : 1,
  
    onSuiteBegin : onSuiteBegin,
    onSuiteEnd : onSuiteEnd,
    routineTimeOut : 60000,
  
    context :
    {
      tempDir : null,
    },
  
    tests :
    {
      exitCode
    }
  
  }
  
  //
  
  Self = wTestSuite( Self );
  if( typeof module !== 'undefined' && !module.parent )
  wTester.test( Self.name );
  
  })();