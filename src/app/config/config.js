// define default config, but allow overrides from ENV vars
let config = {
  APP_DB_HOST: "",
  APP_DB_USER: "",
  APP_DB_PASSWORD: "",
  APP_DB_NAME: ""
}

var AWS = require('aws-sdk');
var client = new AWS.SecretsManager({
    region: "us-east-1"
});

const secretName = "Mydbsecret";

//let APP_DB_USER;

client.getSecretValue({SecretId: secretName}, function(err, data) {
    if (err) {
      config.APP_DB_HOST = "localhost"
      config.APP_DB_NAME = "STUDENTS"
      config.APP_DB_PASSWORD = "student12"
      config.APP_DB_USER = "nodeapp"
      console.log('Secrets not found. Proceeding with default values..')
          //  throw err;
    }
    else {
        if ('SecretString' in data) {
            secret = JSON.parse(data.SecretString);
            for(const envKey of Object.keys(secret)) {
                process.env[envKey] = secret[envKey];
              //  console.log(` Value for key '${envKey}' `);
              //  console.log(` secret[envKey] '${secret[envKey]}'`);
                if (envKey == 'user') {
                  config.APP_DB_USER = secret[envKey]
                } else if (envKey == 'password') {
                  config.APP_DB_PASSWORD = secret[envKey]
                } else if (envKey == 'host') {
                  config.APP_DB_HOST = secret[envKey]
                } else if (envKey == 'db') {
                  config.APP_DB_NAME= secret[envKey]
                }
        }
		
        }

    }
    // console log in case of error
    //console.log(err);
});


Object.keys(config).forEach(key => {
  if(process.env[key] === undefined){
    console.log(`[NOTICE] Value for key '${key}' not found in ENV, using default value.  See app/config/config.js`)
  } else {
    config[key] = process.env[key]
  }
});

module.exports = config;
