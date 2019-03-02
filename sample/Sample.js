
var _ = require( 'wexternalfundamentals' );

debugger
_.shellNode({ path : _.path.join( __dirname, 'Sample2.js' ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  debugger
  return null;
})