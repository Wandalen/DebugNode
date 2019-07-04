if( process.platform === 'linux' )
{
  let _ = require( 'wTools' );
  _.include( 'wLogger' );
  _.include( 'wExternalFundamentals' );
  
  let electronPath = require( 'electron' );
  let electronDistPath = _.path.dir( electronPath );
  
  let commands = [ 'sudo chown root chrome-sandbox', 'sudo chmod 4755 chrome-sandbox' ];
  
  logger.log( 'Setting permissions for chrome-sandbox.');
  
  return _.shell
  ({ 
    execPath : commands,
    currentPath : electronDistPath
  })
}