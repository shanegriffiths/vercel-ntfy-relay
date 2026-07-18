const MAX_NAME_LENGTH = 100;
const MAX_COMMIT_LENGTH = 200;

// Vercel signs webhooks with HMAC-SHA1 of the raw body, hex-encoded,
// sent in the x-vercel-signature header.
async function verifySignature(secret, bodyBytes, signature) {
	if (!signature) return false;
	const key = await crypto.subtle.importKey(
		"raw",
		new TextEncoder().encode(secret),
		{ name: "HMAC", hash: "SHA-1" },
		false,
		["sign"],
	);
	const mac = await crypto.subtle.sign("HMAC", key, bodyBytes);
	const expected = [...new Uint8Array(mac)]
		.map((b) => b.toString(16).padStart(2, "0"))
		.join("");
	if (signature.length !== expected.length) return false;
	let diff = 0;
	for (let i = 0; i < expected.length; i++) {
		diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
	}
	return diff === 0;
}

function json(body, status = 200) {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json" },
	});
}

function clip(value, max) {
	return String(value).slice(0, max);
}

export default {
	async fetch(request, env) {
		if (request.method !== "POST") {
			return new Response("Shipbell relay. POST only.", { status: 405 });
		}

		if (!env.NTFY_TOPIC || !env.VERCEL_WEBHOOK_SECRET) {
			console.error(
				"Missing config: NTFY_TOPIC var and VERCEL_WEBHOOK_SECRET secret are both required",
			);
			return json({ ok: false, error: "Relay not configured" }, 500);
		}

		const bodyBytes = await request.arrayBuffer();
		const signature = request.headers.get("x-vercel-signature");
		if (!(await verifySignature(env.VERCEL_WEBHOOK_SECRET, bodyBytes, signature))) {
			return json({ ok: false, error: "Invalid signature" }, 401);
		}

		let body;
		try {
			body = JSON.parse(new TextDecoder().decode(bodyBytes));
		} catch {
			return json({ ok: false, error: "Invalid JSON" }, 400);
		}

		const eventType = body.type;
		const deployment = body.payload?.deployment || {};
		const target = body.payload?.target || "preview";
		const meta = deployment.meta || {};
		const projectName = clip(
			deployment.name || body.payload?.name || "unknown",
			MAX_NAME_LENGTH,
		);
		const branch = clip(meta.githubCommitRef || "unknown", MAX_NAME_LENGTH);
		const commitMsg = clip(
			(meta.githubCommitMessage || "").split("\n")[0],
			MAX_COMMIT_LENGTH,
		);
		const deployUrl = deployment.url ? `https://${deployment.url}` : "";

		let title, message, tags, priority;

		switch (eventType) {
			case "deployment.succeeded":
				title = `✅ ${projectName} deployed`;
				message = `🌱 ${branch}  →  ${target}${commitMsg ? `\n${commitMsg}` : ""}`;
				tags = ["white_check_mark"];
				priority = 3;
				break;
			case "deployment.error":
				title = `🔥 ${projectName} deploy failed`;
				message = `🌱 ${branch}  →  ${target}${commitMsg ? `\n${commitMsg}` : ""}`;
				tags = ["x"];
				priority = 5;
				break;
			case "deployment.canceled":
				title = `⏹️ ${projectName} deploy cancelled`;
				message = `🌱 ${branch}  →  ${target}`;
				tags = ["stop_button"];
				priority = 2;
				break;
			default:
				return json({ ok: true, ignored: true });
		}

		const ntfyPayload = {
			topic: env.NTFY_TOPIC,
			title,
			message,
			tags,
			priority,
		};
		if (deployUrl) {
			ntfyPayload.click = deployUrl;
		}

		const headers = { "Content-Type": "application/json" };
		if (env.NTFY_TOKEN) {
			headers["Authorization"] = `Bearer ${env.NTFY_TOKEN}`;
		}

		let ntfyResponse;
		try {
			ntfyResponse = await fetch(env.NTFY_URL || "https://ntfy.sh", {
				method: "POST",
				headers,
				body: JSON.stringify(ntfyPayload),
			});
		} catch (err) {
			console.error("ntfy publish failed:", err);
			return json({ ok: false, error: "Publish failed" }, 502);
		}

		if (!ntfyResponse.ok) {
			console.error("ntfy publish failed:", ntfyResponse.status, await ntfyResponse.text());
			return json({ ok: false, error: "Publish failed" }, 502);
		}

		return json({ ok: true, event: eventType, project: projectName });
	},
};
