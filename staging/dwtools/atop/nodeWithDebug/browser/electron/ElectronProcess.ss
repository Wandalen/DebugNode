( function _ElectronProcess_ss_() {

  'use strict';

  if( typeof module !== 'undefined' )
  {

    require( 'wTools' );

    var _ = _global_.wTools;

    _.include( 'wConsequence' );
    _.include( 'wStringsExtra' );
    _.include( 'wExternalFundamentals' );
    _.include( 'wPathFundamentals' );

    var electron = require( 'electron' );

  }

  var app = electron.app;
  var BrowserWindow = electron.BrowserWindow;

  var url = _.appArgs().scriptString;
  var window;

  function windowInit( )
  {
    var o =
    {
      width : 1280,
      height : 720,
      webPreferences :
      {
        nodeIntegration : true
      },
      title : 'DebugNode',
    }

    window = new BrowserWindow( o );

    window.loadURL( url );

    window.webContents.on( 'devtools-focused', () => toogleScreencast() )

    // window.webContents.openDevTools();

    function executeJs( script )
    {
      return _.Consequence.from( window.webContents.executeJavaScript( script,true ) )
    }

    function waitForDebuggerPaused()
    {
      if( !window )
      return;

      var checkPause = 'window.Sources ? window.Sources.SourcesPanel.instance()._paused : false';
      var unPause = 'window.Sources.SourcesPanel.instance()._togglePause()';

      // console.log( 'Check for pause' );

      var con = executeJs( checkPause )
      con.doThen( ( err, got ) =>
      {
        if( got === true )
        {
          clearInterval( interval );
          return executeJs( unPause );
        }
      })
    }

    function toogleScreencast()
    { 
      //to disable annoying blank window on left side that appears on newer versions of node
      var toggleScreencast = 'try{ Screencast.ScreencastApp._appInstance._enabledSetting = false } catch{}';
      executeJs( toggleScreencast );
    }

    var e = /^v(\d+).(\d+).(\d+)/.exec( process.version );
    var nodeVersion =
    {
      major : Number.parseFloat( e[ 1 ] ),
      minor : Number.parseFloat( e[ 2 ] )
    }


    if( nodeVersion.major >= 8 )
    var interval = setInterval( waitForDebuggerPaused,100 );

    window.on( 'closed', function ()
    {
      window = null;
    })

  }

  app.on( 'ready', windowInit );
  app.on( 'browser-window-created', function (e, window )
  {
    window.setMenu( null );
  })

  app.on( 'window-all-closed', function ()
  {
    app.quit();
  });

  app.on( 'activate', function ()
  {
    if ( window === null && !self.headless )
    windowInit();
  })
})();