
var _ = require( 'wappbasic' );

debugger
_.shellNode({ execPath : _.path.join( __dirname, 'Sample3.js' ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  debugger
  return null;
})