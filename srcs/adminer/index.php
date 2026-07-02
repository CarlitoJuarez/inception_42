<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

function adminer_object() {
  class AdminerLoginDefaults extends \Adminer\Adminer {
    function loginForm() {
      $server = htmlspecialchars(getenv('ADMINER_SERVER'), ENT_QUOTES);
      $username = htmlspecialchars(getenv('ADMINER_USERNAME'), ENT_QUOTES);
      $db = htmlspecialchars(getenv('ADMINER_DB'), ENT_QUOTES);

      echo '<form action="" method="post">';
      echo '<table cellspacing="0">';
      echo '<tr><th>System<td><select name="auth[driver]"><option value="server" selected>MySQL</option></select>';
      echo '<tr><th>Server<td><input name="auth[server]" value="' . $server . '">';
      echo '<tr><th>Username<td><input name="auth[username]" value="' . $username . '">';
      echo '<tr><th>Password<td><input type="password" name="auth[password]">';
      echo '<tr><th>Database<td><input name="auth[db]" value="' . $db . '">';
      echo '</table>';
      echo '<p><input type="submit" value="Login">';
      echo '</form>';
    }
  }

  return new AdminerLoginDefaults;
}

include __DIR__ . '/adminer.php';
