
let _ = require( 'wprocess' );

debugger
_.process.startNjs({ execPath : _.path.join( __dirname, 'Sample3.s' ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  debugger
  return null;
})
