(function () {
  var phases = ["init", "brainstorming", "writing-plans", "executing-plans", "loop-refined", "commit-code", "done"];
  function qs(id) { return document.getElementById(id); }

  function readParam(name) {
    var m = new URLSearchParams(location.search).get(name);
    return m || "";
  }

  function render(data) {
    var meta = qs("meta");
    meta.innerHTML = "<div>requirement_key: <code>" + (data.requirement_key || "-") + "</code></div>" +
      "<div>feature_branch: <code>" + (data.feature_branch || "-") + "</code></div>";

    var timeline = qs("timeline");
    var current = data.current_phase || "init";
    timeline.innerHTML = phases.map(function (p) {
      var cls = p === current ? "node active" : "node";
      return '<span class="' + cls + '">' + p + '</span>';
    }).join("");

    var repoRows = qs("repoRows");
    repoRows.innerHTML = (data.repos || []).map(function (r) {
      return "<tr><td>" + r.name + "</td><td><code>" + (r.branch || "-") + "</code></td><td>" + (r.phase || "-") + "</td></tr>";
    }).join("");

    var issueRows = qs("issueRows");
    issueRows.innerHTML = (data.rounds || []).map(function (r) {
      return "<tr><td>" + r.round + "</td><td><span class='tag open'>" + r.open + "</span></td><td><span class='tag closed'>" + r.closed + "</span></td></tr>";
    }).join("");
  }

  function fallback() {
    render({
      requirement_key: readParam("requirement_key") || "demo_requirement",
      feature_branch: readParam("feature_branch") || "feature_demoFlowAlign",
      current_phase: readParam("phase") || "brainstorming",
      repos: [
        { name: "main-repo", branch: "feature_demoFlowAlign", phase: readParam("phase") || "brainstorming" },
        { name: "dep-service-a", branch: "feature_demoFlowAlign", phase: readParam("phase") || "brainstorming" }
      ],
      rounds: [
        { round: 1, open: 3, closed: 0 },
        { round: 2, open: 1, closed: 2 },
        { round: 3, open: 0, closed: 3 }
      ]
    });
  }

  fetch("./state.json", { cache: "no-store" })
    .then(function (r) { if (!r.ok) { throw new Error("state not found"); } return r.json(); })
    .then(render)
    .catch(fallback);
})();
