class profile::realadmin (

  Hash[String,Struct[{
    listen => String,
    doc_root => String,
  }]]                                 $virtualhosts         = {},
  Hash[String,Struct[{
    listen => String,
    doc_root => String,
  }]]                                 $webvirtualhosts         = {},
  Boolean                             $ssl                  = false,
  Optional[String]  $db_password    = $profile::realadmin::db_password,
  Optional[String]  $bind_address   = $profile::realadmin::bind_address,
  Optional[String]  $redis_password = $profile::realadmin::redis_password,
  Optional[String]  $redis_bind_address = $profile::realadmin::redis_bind_address,
  Array[Integer] $location = [],

) inherits ::profile {


#fastcgi parmas
file { '/etc/nginx/fastcgi_params_ppm':
  ensure => present,
  source => 'puppet:///modules/profile/crm/fastcgi_params_ppm',
  notify => Service['nginx'],
}

#virtualhostweb setup
$webvirtualhosts.each |$virtualhost, $opts| {

nginx::resource::server { "${virtualhost}":
listen_port         => Stdlib::Port($opts[listen]),
www_root            => "${opts['doc_root']}",
ssl                 => $ssl,
ssl_cert    => if $ssl { "/etc/letsencrypt/live/${virtualhost}/fullchain.pem" },
ssl_key     => if $ssl { "/etc/letsencrypt/live/${virtualhost}/privkey.pem" },
ssl_redirect        => $ssl,
server_cfg_prepend => {
                     root  => Stdlib::Absolutepath($opts[doc_root]),
},
location_cfg_append    => {
                    try_files => '$uri $uri/ /index.php',
},
}
$dest_dir=Stdlib::Absolutepath($opts[doc_root])
file { "${dest_dir}" :
ensure => directory,
}

nginx::resource::location { "~ \.php$-${virtualhost}":
location => '~ \.php$',
index_files => [],
server => "${virtualhost}",
ssl_only    => $ssl,
location_cfg_append => {
  include => '/etc/nginx/fastcgi_params_ppm',
  fastcgi_param => 'SCRIPT_FILENAME    $request_filename',
},
}

nginx::resource::location { "~ /\.-${virtualhost}":
location => '~ /\.',
location_cfg_append => {
  deny => 'all',
  return => '444',
  access_log => 'off',
},
ssl_only    => $ssl,
index_files => [],
server => "${virtualhost}",
}

}
#virtualhost setup
$virtualhosts.each |$virtualhost, $opts| {

nginx::resource::server { "${virtualhost}":
  listen_port         => Stdlib::Port($opts[listen]),
  www_root            => "${opts['doc_root']}",
  ssl                 => $ssl,
  ssl_cert    => if $ssl { "/etc/letsencrypt/live/${virtualhost}/fullchain.pem" },
  ssl_key     => if $ssl { "/etc/letsencrypt/live/${virtualhost}/privkey.pem" },
  ssl_redirect        => $ssl,
  include_files       => [ "/etc/nginx/versions/${virtualhost}" ],
  server_cfg_ssl_prepend => {
                       root  => Stdlib::Absolutepath($opts[doc_root]),
  },
  location_cfg_append    => {
                      try_files => '$uri $uri/ /index.php',
  },
}
$dest_dir=Stdlib::Absolutepath($opts[doc_root])
file { "${dest_dir}" :
  ensure => directory,
}

nginx::resource::location { "~ \.php$-${virtualhost}":
  location => '~ \.php$',
  index_files => [],
  server => "${virtualhost}",
  ssl_only    => $ssl,
  location_cfg_append => {
    include => '/etc/nginx/fastcgi_params_ppm',
    fastcgi_param => 'SCRIPT_FILENAME    $request_filename',
  },
}
nginx::resource::location { "~ /\.-${virtualhost}":
  location => '~ /\.',
  location_cfg_append => {
    deny => 'all',
    return => '444',
    access_log => 'off',
  },
  ssl_only    => $ssl,
  index_files => [],
  server => "${virtualhost}",
}

#version location file creation as well as directory

  file { "/etc/nginx/versions/${virtualhost}" :
    ensure => present,
    content => template("profile/realadmin/version.erb"),
    purge   => true,
    notify => Service['nginx'],
  }
#dir path handling
$location.each |$location| {
  file { "${dest_dir}/v${location}" :
    ensure => directory,
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/application/config" :
    ensure => present,
    source => 'puppet:///modules/profile/crm/application/config/',
    recurse => true,
    notify => Service['nginx'],
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/application/config/database.php" :
    ensure => present,
    content => template("profile/realadmin/config/database.php.erb"),
    notify => Service['nginx'],
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/application/config/constants.php" :
    ensure => present,
    content => template("profile/realadmin/config/constants.php.erb"),
    notify => Service['nginx'],
  }
file { "/usr/share/nginx/html/realadmin/v${location}/index.php" :
    ensure => present,
    source => 'puppet:///modules/profile/realadmin/index.php',
    notify => Service['nginx'],
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/application/config/redis.php" :
    ensure => present,
    content => template("profile/realadmin/config/redis.php.erb"),
    notify => Service['nginx'],
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/application/config/codeigniter-predis.php" :
    ensure => present,
    content => template("profile/realadmin/config/codeigniter-predis.php.erb"),
    notify => Service['nginx'],
  }
  file { "/usr/share/nginx/html/realadmin/v${location}/system/" :
    ensure => present,
    source => 'puppet:///modules/profile/crm/system',
    recurse => true,
    purge => true,
    notify => Service['nginx'],
  }

   file { [ '/usr/share/nginx/html/realadmin/oss','/usr/share/nginx/html/realadmin/oss/uploads','/usr/share/nginx/html/realadmin/oss/uploads/club','/usr/share/nginx/html/realadmin/oss/uploads/club/banner' ] :
    ensure => directory,
    owner => 'www-data',
    mode  => '0755',
    group => 'www-data',
    }


}
#php setup
class { '::php::globals':
  php_version => '7.4',

}->
class { '::php':
  ensure  => 'present',
  manage_repos => false,
  fpm          => false,
  cli_settings => {
    'PHP/max_execution_time' => '600',
    'PHP/track_errors'  => 'Off',
    'PHP/html_errors'   => 'On',
    'PHP/post_max_size' => '8M',
    'Pdo_mysql/pdo_mysql.cache_size' => '2000',
    'MySQLi/mysqli.cache_size'    => '2000',

  },
  extensions => {
    curl => { },
    odbc  => { },
    mysql  => { },
    pgsql  => { },
    gd =>  { },
  },
}
class { 'phpfpm':
  poold_purge    => true,
}
phpfpm::pool { 'www':
    listen => '127.0.0.1:9000',
    listen_owner => 'www-data',
    listen_group => 'www-data',
    listen_allowed_clients => '127.0.0.1',
    pm                     => 'dynamic',
    pm_max_children        => 300,
    pm_start_servers       => 60,
    pm_min_spare_servers   => 60,
    pm_max_spare_servers   => 60,
    pm_process_idle_timeout => '10s',
    pm_max_requests => '1000',
    request_terminate_timeout => '600s',
    catch_workers_output      => 'yes',
}

file { [ '/usr/share/nginx/sessions', '/usr/share/nginx/sessions/api' ] :
  ensure => directory,
  mode   => '0755',
  owner  => 'www-data',
  group  => 'www-data',
}

include profile::utilities::phpsession_cleanup
#location setup

}
