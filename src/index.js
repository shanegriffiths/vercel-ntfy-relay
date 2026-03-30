export default {
	async fetch(request, env) {
		if (request.method !== "POST") {
			return new Response("Vercel → ntfy relay. POST only.", { status: 405 });
		}

		let body;
		try {
			body = await request.json();
		} catch {
			return new Response("Invalid JSON", { status: 400 });
		}

		const eventType = body.type;
		const deployment = body.payload?.deployment || {};
		const target = body.payload?.target || "preview";
		const meta = deployment.meta || {};
		const projectName = deployment.name || body.payload?.name || "unknown";
		const branch = meta.githubCommitRef || "unknown";
		const commitMsg = meta.githubCommitMessage || "";
		const deployUrl = deployment.url ? `https://${deployment.url}` : "";

		let title, message, tags, priority;

		switch (eventType) {
			case "deployment.succeeded":
				title = `✅ ${projectName} deployed`;
				message = `🌱 ${branch}  →  ${target}${commitMsg ? `\n${commitMsg.split("\n")[0]}` : ""}`;
				tags = ["white_check_mark"];
				priority = 3;
				break;
			case "deployment.error":
				title = `🔥 ${projectName} deploy failed`;
				message = `🌱 ${branch}  →  ${target}${commitMsg ? `\n${commitMsg.split("\n")[0]}` : ""}`;
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
				return new Response(`Ignored event: ${eventType}`, { status: 200 });
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

		const ntfyResponse = await fetch("https://ntfy.sh", {
			method: "POST",
			headers,
			body: JSON.stringify(ntfyPayload),
		});

		const ntfyBody = await ntfyResponse.text();

		return new Response(
			JSON.stringify({
				ok: ntfyResponse.ok,
				status: ntfyResponse.status,
				event: eventType,
				project: projectName,
				ntfyResponse: ntfyBody,
			}),
			{
				status: 200,
				headers: { "Content-Type": "application/json" },
			},
		);
	},
};
