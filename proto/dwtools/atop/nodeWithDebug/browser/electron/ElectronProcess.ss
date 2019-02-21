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
    var ipc = require('node-ipc');

  }

  var app = electron.app;
  var BrowserWindow = electron.BrowserWindow;
  var globalShortcut = electron.globalShortcut;

  var url = _.appArgs().scriptString;
  var window;
  let ready = new _.Consequence();

  /*  */

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
      ipc.of.nodewithdebug.emit( 'reload', { type : 'reload' } );
    })

    toogleScreencast();

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

  /*  */

  function setup()
  {
    ipc.config.id = 'electon';
    ipc.config.retry = 1500;
    ipc.config.silent = true;

    ipc.connectTo( 'nodewithdebug', () =>  ready.take( null ) );

    ready.thenKeep( () =>
    {
      ipc.of.nodewithdebug.on( 'newNodeElectron', ( data ) =>
      {
        var url = data.message.url;
        _.assert( _.strIs( url ) )

        var o =
        {
          parent: window,
          modal: false,
          width : 1280,
          height : 720,
          webPreferences :
          {
            nodeIntegration : true
          },
          title : 'DebugNode',
          show: false
        }
        let child = new BrowserWindow( o );

        child.loadURL( url );

        child.once( 'ready-to-show', () =>
        {
          child.show();
        })

      });

      /*  */

      app.on( 'ready', windowInit );
      app.on( 'browser-window-created', function (e, window )
      {
        window.setMenu( null );
      })

      app.on( 'window-all-closed', function ()
      {
        // ipc.of.nodewithdebug.emit( 'electronExit', { id : ipc.config.id, message : 'exit' } ); //qqq : problem, process hangs
        app.quit();
      });

      app.on( 'activate', function ()
      {
        if ( window === null && !self.headless )
        windowInit();
      })

      /*  */

      return true;

    })

  }

  setup();

})();