( function _ElectronProcess_ss_() {

  'use strict';

  if( typeof module !== 'undefined' )
  {

    require( 'wTools' );

    var _ = _global_.wTools;

    _.include( 'wConsequence' );
    _.include( 'wStringsExtra' );
    _.include( 'wAppBasic' );
    _.include( 'wPathBasic' );

    var electron = require( 'electron' );
    var ipc = require('node-ipc');

  }

  var app = electron.app;
  var BrowserWindow = electron.BrowserWindow;
  var globalShortcut = electron.globalShortcut;

  var url = _.appArgs().scriptString;
  var window;

  ipc.config.id = 'electon';
  ipc.config.retry = 1500;
  ipc.config.silent = true;
  ipc.connectTo( 'main', ipcConnectHandler );

  function ipcConnectHandler()
  {
    ipc.of.main.on( 'message', ipcOnMessageHandler );
  }

  function ipcOnMessageHandler( msg )
  {
    if( msg.type === 'loadURL' )
    {
      _.assert( _.strIs( msg.uri ) )
      window.loadURL( msg.uri );
    }
  }

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

    globalShortcut.register( 'F5', () =>
    {
      if( window.isFocused() )
      ipc.of.main.emit( 'message', { type : 'reload' } );
    })

    toogleScreencast()

    // window.webContents.openDevTools();

    function executeJs( script )
    {
      return _.Consequence.From( window.webContents.executeJavaScript( script,true ) )
    }

    function waitForDebuggerPaused()
    {
      if( !window )
      return;

      var checkPause = 'window.Sources ? window.Sources.SourcesPanel.instance()._paused : false';
      var unPause = 'window.Sources.SourcesPanel.instance()._togglePause()';

      // console.log( 'Check for pause' );

      var con = executeJs( checkPause )
      con.finally( ( err, got ) =>
      {
        if( got === true )
        {
          clearInterval( interval );
          return executeJs( unPause );
        }
        return true;
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


    // if( nodeVersion.major >= 8 )
    // var interval = setInterval( waitForDebuggerPaused,100 );

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
    ipc.of.main.emit( 'message', { type : 'quit' } );
    app.quit();
  });

  app.on( 'activate', function ()
  {
    if ( window === null && !self.headless )
    windowInit();
  })
})();