let ansi = require ( 'ansicolor' )
let hasAnsi = require( 'has-ansi' );
let _ = require( 'wConsequence' );
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
