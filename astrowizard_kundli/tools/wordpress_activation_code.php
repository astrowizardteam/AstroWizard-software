<?php
/**
 * AstroWizard activation codes for WordPress (add via the "Code Snippets" plugin
 * or your child theme's functions.php).
 *
 * 1. Put the secret in wp-config.php (NOT in the theme):
 *      define('AW_APP_SECRET', 'the same value as the GitHub secret AW_SECRET');
 * 2. Call aw_make_code($days) after a successful Razorpay payment and show / email
 *    the code to the customer. Example for WooCommerce is at the bottom; adjust it
 *    to however your Razorpay payment is recorded.
 *
 * Layout (same as tools/make_code.py): days(2) | issue day since 2024-01-01 (2) |
 * random id (3) | HMAC-SHA256(secret, first 7 bytes)[0..5], Crockford base32,
 * shown as XXXXX-XXXXX-XXXXX-XXXXX. Untested on your server: try one code in the app first.
 */
function aw_make_code(int $days): string {
    $alpha = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    $issue = (int) floor((time() - gmmktime(0, 0, 0, 1, 1, 2024)) / 86400);
    $id = random_int(0, 0xFFFFFF);
    $payload = pack('nn', $days, $issue) . substr(pack('N', $id), 1);
    $mac = substr(hash_hmac('sha256', $payload, AW_APP_SECRET, true), 0, 5);
    $bits = '';
    foreach (str_split($payload . $mac) as $ch) {
        $bits .= str_pad(decbin(ord($ch)), 8, '0', STR_PAD_LEFT);
    }
    $bits .= str_repeat('0', (5 - strlen($bits) % 5) % 5);
    $code = '';
    foreach (str_split($bits, 5) as $five) {
        $code .= $alpha[bindec($five)];
    }
    return implode('-', str_split($code, 5));
}

/* ---- Example (WooCommerce): email a code when an order is completed.
 * Days per product: edit the map (product ID => days).
add_action('woocommerce_order_status_completed', function ($order_id) {
    $map = [123 => 30, 124 => 365];            // product ID => validity in days
    $order = wc_get_order($order_id);
    foreach ($order->get_items() as $item) {
        $days = $map[$item->get_product_id()] ?? 0;
        if ($days) {
            $code = aw_make_code($days);
            $order->add_order_note("App activation code: $code");
            wp_mail($order->get_billing_email(), 'Your AstroWizard app code',
                "Thank you! Open the app, tap Recharge, enter this code:\n\n$code\n\nValidity: $days days.");
        }
    }
});
*/
