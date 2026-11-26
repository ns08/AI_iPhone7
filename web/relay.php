<?php
header("Content-Type: application/json; charset=utf-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");

$storageDir = __DIR__ . "/storage";
if (!is_dir($storageDir)) {
    mkdir($storageDir, 0775, true);
}

$raw = file_get_contents("php://input");
$data = json_decode($raw ?: "{}", true);
if (!is_array($data)) {
    http_response_code(400);
    echo json_encode(["ok" => false, "error" => "Invalid JSON"]);
    exit;
}

$deviceId = preg_replace("/[^a-zA-Z0-9_-]/", "", $data["device_id"] ?? "iphone7-main");
$queueFile = "$storageDir/{$deviceId}_queue.json";

$role = $data["role"] ?? "controller";
$type = $data["type"] ?? "";

if ($role === "device") {
    $commands = [];
    if (file_exists($queueFile)) {
        $commands = json_decode(file_get_contents($queueFile), true) ?: [];
        file_put_contents($queueFile, json_encode([]));
    }
    echo json_encode(["ok" => true, "commands" => $commands]);
    exit;
}

$queue = file_exists($queueFile) ? (json_decode(file_get_contents($queueFile), true) ?: []) : [];
$data["queued_at"] = microtime(true);
$queue[] = $data;
file_put_contents($queueFile, json_encode($queue));

$statusMsg = match ($type) {
    "amazon_order" => "Amazonで「" . ($data["query"] ?? "") . "」を検索します。",
    "play_local_music" => "本体音楽再生コマンド「" . ($data["query"] ?? "") . "」を送信しました。",
    "voice_command" => "音声コマンド「" . ($data["text"] ?? "") . "」を送信しました。",
    default => ""
};

echo json_encode([
    "ok" => true,
    "status_message" => $statusMsg
]);
