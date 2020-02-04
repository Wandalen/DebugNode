let ansi = require ( 'ansicolor' )
let hasAnsi = require( 'has-ansi' );
let _ = require( 'wTools' );
_.include( 'wConsequence' )
_.include( 'wPathBasic' )
let electron = require('electron');

ansi.rgb =
{
    black:        [0,     0,   0],
    darkGray:     [100, 100, 100],
    lightGray:    [200, 200, 200],
    white:        [255, 255, 255],

    red:          [255,   0,   0],
    lightRed:     [255,  51,   0],

    green:        [0,   255,   0],
    lightGreen:   [51,  204,  51],

    yellow:       [255, 153,  51],
    lightYellow:  [255, 255,  0],

    blue:         [0,     0, 255],
    lightBlue:    [26,  140, 255],

    magenta:      [204,   0, 204],
    lightMagenta: [255,   0, 255],

    cyan:         [0,   204, 255],
    lightCyan:    [0,   255, 255],
}

window.onload = function()
{   
  window.electronWidnow = electron.remote.getCurrentWindow();
  
  /**/
  
  let original = SDK.consoleModel.addMessage;
  SDK.consoleModel.addMessage = function addMessage( message )
  { 
    if( hasAnsi( message.messageText ) )
    {
      let parsed = ansi.parse( message.messageText );
      message.parameters = parsed.asChromeConsoleLogArguments;
      message.messageText = message.parameters[ 0 ];
    }
    
    if( message.level === "error" )
    {
      message.messageText = _.path.normalize( message.messageText );
      
      let regexps = [ /(@ )(.*\:[0-9]+\:[0-9]+)/gm, /(\()(.*\:[0-9]+\:[0-9]+)(\))/gm ]
      
      regexps.forEach(( r ) => 
      {
        message.messageText = _.strReplaceAll( message.messageText, r, ( match, it ) => 
        { 
          it.groups[ 1 ] = _.path.normalize( it.groups[ 1 ] );
          
          if( _.path.isRelative( it.groups[ 1 ] ) )
          return it.groups.join( '' );
          
          it.groups[ 1 ] = _.path.nativize( it.groups[ 1 ] );
          it.groups[ 1 ] = _.strReplaceAll( it.groups[ 1 ], '\\', '/' );
          it.groups[ 1 ] = `file:///${it.groups[ 1 ]}`;
          return it.groups.join( '' );
        })
      })
      
      
      message.parameters[ 0 ].value = message.messageText;
    }
    
    original.call( SDK.consoleModel, message );
  }
    
  /**/
  
  focusWindowOnDebuggerPause();
  
  /**/

  closeWindowOnDisconnect();
}


function closeWindowOnDisconnect()
{
  let con = new wConsequence();

  SDK.targetManager.addModelListener
  (
    SDK.RuntimeModel,
    SDK.RuntimeModel.Events.ExecutionContextDestroyed,
    () => con.take( true ),
    this
  );

  con.thenKeep( ( finallyGive ) =>
  {
    if( finallyGive )
    window.close();

    return finallyGive;
  })
}

//

function focusWindowOnDebuggerPause()
{ 
  SDK.targetManager.addModelListener
  (
    SDK.DebuggerModel,
    SDK.DebuggerModel.Events.DebuggerPaused,
    handler,
    this
  );
  
  function handler()
  {
    if( !electronWidnow.isFocused() )
    electronWidnow.focus();
  }
}
