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

  var window;
  let ready = new _.Consequence();
  let nodes = Object.create( null );

  /*  */

  launch();

  /*  */

  function masterInit( o )
  {
    let workArea = electron.screen.getPrimaryDisplay().workAreaSize; // window.maximize() works with some artifact

    var options =
    {
      width : workArea.width,
      height : workArea.height,
      webPreferences :
      {
        nodeIntegration : true,
        preload : _.path.nativize( _.path.join( __dirname, 'ElectronPreload.ss' ) )
      },
      title : o.title + ' [main]'
    }

    window = new BrowserWindow( options );

    window.loadURL( o.url );

    // window.webContents.openDevTools();

    window.on( 'closed', function ()
    {
      window = null;
    })

    return true;
  }


  function childInit( o )
  {
    _.assert( window );

    var options =
    {
      parent: window,
      modal: false,
      width : 1280,
      height : 720,
      webPreferences :
      {
        nodeIntegration : true,
        preload : _.path.nativize( _.path.join( __dirname, 'ElectronPreload.ss' ) )
      },
      title : o.title,
      show: false
    }

    let child = new BrowserWindow( options );
    let pid = o.pid;

    nodes[ pid ] = child;

    child.loadURL( o.url );
    
    child.on( 'closed', function ()
    {
      ipc.of.nodewithdebug.emit( 'electronChildClosed', { id : ipc.config.id, message : { pid : pid } } );
    })

    child.once( 'ready-to-show', () =>
    {
      child.show();
    })

    return true;
  }

  //

  function launch()
  {
    process.on( 'message', ( msg ) =>
    {
      if( msg.exit )
      app.quit()
    })

    setupIpc();

    app.on( 'ready', () => ready.take( true ) );

    app.on('window-all-closed', () =>  app.quit() )

    app.on( 'browser-window-created', function (e, window )
    {
      window.setMenu( null );
    })

  }

  function setupIpc()
  {
    let con = new _.Consequence();

    ipc.config.id = 'electon';
    ipc.config.retry = 1500;
    ipc.config.silent = false;

    ipc.connectTo( 'nodewithdebug', () =>
    {
      /* creates window for new node process */

      ipc.of.nodewithdebug.on( 'newNodeElectron', ( data ) =>
      {
        var o = data.message;

        console.log( o )

        if( o.isMaster )
        ready.then( () => masterInit( o ) );
        else
        ready.then( () => childInit( o ) );

      });

      /*  */

      ipc.of.nodewithdebug.emit( 'electronReady', { id : ipc.config.id, message : { ready : 1 } } );

    });

  }

})();

/*  */

// function experiment()
// {
//   const { app, BrowserWindow } = require('electron')

//   process.on( 'message', ( msg ) =>
//   {
//     if( msg.exit )
//     app.quit()
//   })

//   let win

//   function createWindow () {
//     win = new BrowserWindow({ width: 800, height: 600 })

//     win.loadURL('https://electronjs.org/docs/tutorial/first-app')

//     win.webContents.openDevTools()

//     win.on('closed', () => {
//       win = null
//     })
//   }

//   app.on('ready', createWindow)

//   app.on('window-all-closed', () => {
//     if (process.platform !== 'darwin') {
//       app.quit()
//     }
//   })

//   app.on('activate', () => {
//     if (win === null) {
//       createWindow()
//     }
//   })
// }


