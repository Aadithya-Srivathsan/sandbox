cat <<'EOF' > app.py
from flask import Flask, request, jsonify, render_template
from openai import AzureOpenAI
import os

client = AzureOpenAI(
    azure_endpoint=os.getenv("OPENAI_ENDPOINT"),
    api_key=os.getenv("OPENAI_API_KEY"),
    api_version="2025-03-01-preview"
)

DEPLOYMENT = os.getenv("OPENAI_DEPLOYMENT_NAME")

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/chat", methods=["POST"])
def chat():
    user_message = request.json.get("message")

    response = client.responses.create(
        model=DEPLOYMENT,
        input=user_message
    )

    reply = response.output[0].content[0].text
    return jsonify({"reply": reply})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF


########################################################################################


mkdir templates
cat <<'EOF' > templates/index.html
<!DOCTYPE html>
<html>
<head>
  <title>GenAI Chatbot</title>
  <style>
    body { font-family: Arial; background: #f4f4f4; }
    .chat { width: 400px; margin: 50px auto; background: white; padding: 20px; }
    input { width: 80%; padding: 10px; }
    button { padding: 10px; }
    .msg { margin: 10px 0; }
  </style>
</head>
<body>
  <div class="chat">
    <h3>GenAI Chatbot</h3>
    <div id="messages"></div>
    <input id="input" placeholder="Type message..." />
    <button onclick="send()">Send</button>
  </div>

<script>
function send() {
  let msg = document.getElementById("input").value;
  fetch("/api/chat", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({message: msg})
  })
  .then(r => r.json())
  .then(d => {
    document.getElementById("messages").innerHTML +=
      `<div class='msg'><b>You:</b> ${msg}</div>
       <div class='msg'><b>Bot:</b> ${d.reply}</div>`;
  });
}
</script>
</body>
</html>
EOF
