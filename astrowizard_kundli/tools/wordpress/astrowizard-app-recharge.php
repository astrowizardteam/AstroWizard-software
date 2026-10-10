<?php
/**
 * Plugin Name: AstroWizard App Recharge
 * Description: Razorpay recharge for the AstroWizard Kundali Software app. Keeps the paid validity per phone, so access survives "clear data".
 * Version: 1.0
 *
 * SETUP
 * 1. Upload this file to wp-content/plugins/astrowizard-app-recharge/ (or paste into the Code Snippets plugin) and activate.
 * 2. In wp-config.php add (before "That's all, stop editing"):
 *      define('AW_APP_SECRET',        'same value as the GitHub secret AW_SECRET');
 *      define('AW_RZP_KEY_ID',        'rzp_live_xxxxxxxx');
 *      define('AW_RZP_KEY_SECRET',    'razorpay key secret');
 *      define('AW_RZP_WEBHOOK_SECRET','the secret you set on the Razorpay webhook');
 * 3. Create the page www.astrowizard.co.in/apprecharge and put the shortcode [aw_app_recharge] in it.
 * 4. Razorpay Dashboard > Settings > Webhooks > add
 *      https://www.astrowizard.co.in/wp-json/astrowizard/v1/razorpay
 *    event: payment.captured (also order.paid), with the webhook secret from step 2.
 * 5. Edit the plans below (the amounts are PLACEHOLDERS) .
 *
 * Endpoints (used by the app):
 *   GET  /wp-json/astrowizard/v1/status?device=ID   -> {"exp": unix seconds (0 = none), "sig": "..."}
 *   POST /wp-json/astrowizard/v1/order              -> creates a Razorpay order (used by the page)
 *   POST /wp-json/astrowizard/v1/razorpay           -> Razorpay webhook, extends the validity
 * Untested on a live server: make one small test payment first.
 */
if (!defined('ABSPATH')) { exit; }

/** Plans: id => [label, days, amount in paise (100 paise = Rs 1)]. EDIT THESE. */
function aw_plans() {
    return [
        'm1'  => ['label' => '30 days',  'days' => 30,  'amount' => 9900],   // Rs 99  (placeholder)
        'm6'  => ['label' => '6 months', 'days' => 180, 'amount' => 49900],  // Rs 499 (placeholder)
        'y1'  => ['label' => '1 year',   'days' => 365, 'amount' => 89900],  // Rs 899 (placeholder)
    ];
}

function aw_valid_device($d) { return is_string($d) && preg_match('/^[A-Za-z0-9_-]{8,64}$/', $d); }
function aw_opt($device) { return 'aw_exp_' . md5($device); }
function aw_get_exp($device) { return (int) get_option(aw_opt($device), 0); }
function aw_status_sig($device, $exp) { return substr(hash_hmac('sha256', $device . ':' . $exp, AW_APP_SECRET), 0, 16); }

/** Adds days to the device validity (starting from now or the current expiry). */
function aw_extend($device, $days) {
    $cur = aw_get_exp($device);
    $base = max($cur, time());
    $new = $base + $days * 86400;
    update_option(aw_opt($device), $new, false);
    return $new;
}

add_action('rest_api_init', function () {
    register_rest_route('astrowizard/v1', '/status', [
        'methods' => 'GET', 'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $r) {
            $device = (string) $r->get_param('device');
            if (!aw_valid_device($device)) { return new WP_REST_Response(['error' => 'bad device'], 400); }
            $exp = aw_get_exp($device);
            $res = new WP_REST_Response(['exp' => $exp, 'sig' => aw_status_sig($device, $exp)]);
            $res->header('Cache-Control', 'no-store');
            return $res;
        },
    ]);

    register_rest_route('astrowizard/v1', '/order', [
        'methods' => 'POST', 'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $r) {
            $device = (string) $r->get_param('device');
            $session = preg_replace('/[^A-Za-z0-9]/', '', (string) $r->get_param('session'));
            $plans = aw_plans();
            $plan = (string) $r->get_param('plan');
            if (!aw_valid_device($device) || !isset($plans[$plan])) {
                return new WP_REST_Response(['error' => 'bad request'], 400);
            }
            $p = $plans[$plan];
            $resp = wp_remote_post('https://api.razorpay.com/v1/orders', [
                'headers' => ['Authorization' => 'Basic ' . base64_encode(AW_RZP_KEY_ID . ':' . AW_RZP_KEY_SECRET),
                              'Content-Type' => 'application/json'],
                'body' => wp_json_encode([
                    'amount' => $p['amount'], 'currency' => 'INR',
                    'receipt' => 'app_' . substr($session, 0, 12),
                    'notes' => ['device' => $device, 'session' => $session, 'plan' => $plan],
                ]),
                'timeout' => 20,
            ]);
            if (is_wp_error($resp)) { return new WP_REST_Response(['error' => 'razorpay unreachable'], 502); }
            $o = json_decode(wp_remote_retrieve_body($resp), true);
            if (empty($o['id'])) { return new WP_REST_Response(['error' => 'order failed'], 502); }
            return new WP_REST_Response(['order_id' => $o['id'], 'key' => AW_RZP_KEY_ID,
                                         'amount' => $p['amount'], 'label' => $p['label']]);
        },
    ]);

    register_rest_route('astrowizard/v1', '/razorpay', [
        'methods' => 'POST', 'permission_callback' => '__return_true',
        'callback' => function (WP_REST_Request $r) {
            $body = $r->get_body();
            $sig = $r->get_header('x_razorpay_signature');
            if (!$sig || !hash_equals(hash_hmac('sha256', $body, AW_RZP_WEBHOOK_SECRET), $sig)) {
                return new WP_REST_Response(['error' => 'bad signature'], 400);
            }
            $e = json_decode($body, true);
            $event = $e['event'] ?? '';
            if (!in_array($event, ['payment.captured', 'order.paid'], true)) {
                return new WP_REST_Response(['ok' => true, 'ignored' => $event]);
            }
            $pay = $e['payload']['payment']['entity'] ?? [];
            $notes = $pay['notes'] ?? [];
            $pid = $pay['id'] ?? '';
            $device = $notes['device'] ?? '';
            $plans = aw_plans();
            $plan = $notes['plan'] ?? '';
            if (!$pid || !aw_valid_device($device) || !isset($plans[$plan])) {
                return new WP_REST_Response(['ok' => true, 'ignored' => 'no app notes']);
            }
            if ((int) ($pay['amount'] ?? 0) !== $plans[$plan]['amount']) {
                return new WP_REST_Response(['ok' => true, 'ignored' => 'amount mismatch']);
            }
            $key = 'aw_paid_' . md5($pid);
            if (get_option($key)) { return new WP_REST_Response(['ok' => true, 'dup' => true]); }  // Razorpay may retry
            update_option($key, 1, false);
            aw_extend($device, $plans[$plan]['days']);
            return new WP_REST_Response(['ok' => true]);
        },
    ]);
});

/** [aw_app_recharge] : the page the app opens (?device=...&session=...). */
add_shortcode('aw_app_recharge', function () {
    $device = isset($_GET['device']) ? sanitize_text_field(wp_unslash($_GET['device'])) : '';
    $session = isset($_GET['session']) ? preg_replace('/[^A-Za-z0-9]/', '', wp_unslash($_GET['session'])) : '';
    if (!aw_valid_device($device)) {
        return '<p>Please open this page from the AstroWizard app (Recharge button).</p>';
    }
    $exp = aw_get_exp($device);
    $html = '<div id="aw-recharge" style="max-width:420px;margin:auto">';
    $html .= '<h3>Recharge AstroWizard Kundali Software</h3>';
    if ($exp > time()) { $html .= '<p>Current plan active until ' . esc_html(wp_date('d M Y, H:i', $exp)) . '. A new recharge is added after it.</p>'; }
    foreach (aw_plans() as $id => $p) {
        $html .= '<p><button class="awpay" data-plan="' . esc_attr($id) . '" style="width:100%;padding:12px;font-size:16px">'
              . esc_html($p['label']) . ' &mdash; &#8377;' . esc_html(number_format($p['amount'] / 100)) . '</button></p>';
    }
    $html .= '<p id="aw-msg"></p></div>';
    $html .= '<script src="https://checkout.razorpay.com/v1/checkout.js"></script><script>
    (function(){
      var device=' . wp_json_encode($device) . ', session=' . wp_json_encode($session) . ';
      var msg=document.getElementById("aw-msg");
      document.querySelectorAll(".awpay").forEach(function(b){ b.onclick=function(){
        msg.textContent="Please wait...";
        fetch(' . wp_json_encode(esc_url_raw(rest_url('astrowizard/v1/order'))) . ',{method:"POST",headers:{"Content-Type":"application/json"},
          body:JSON.stringify({device:device,session:session,plan:b.dataset.plan})})
        .then(function(r){return r.json();}).then(function(o){
          if(!o.order_id){msg.textContent="Could not start the payment. Try again.";return;}
          new Razorpay({key:o.key,amount:o.amount,currency:"INR",order_id:o.order_id,name:"AstroWizard",
            description:"App recharge: "+o.label,
            handler:function(){msg.innerHTML="<b>Payment received.</b> Go back to the app and tap <i>I have recharged: check status</i>.";},
            modal:{ondismiss:function(){msg.textContent="";}}}).open();
        }).catch(function(){msg.textContent="Network error. Try again.";});
      };});
    })();</script>';
    return $html;
});
