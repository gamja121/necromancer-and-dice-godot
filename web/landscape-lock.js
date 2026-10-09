(() => {
  const coarsePointer = matchMedia("(pointer: coarse)").matches;
  const touchCapable = coarsePointer || navigator.maxTouchPoints > 0 || "ontouchstart" in window;
  if (!touchCapable) return;

  const gate = document.createElement("div");
  gate.id = "landscape-gate";
  gate.setAttribute("role", "dialog");
  gate.setAttribute("aria-modal", "true");
  gate.innerHTML = [
    '<div class="landscape-card">',
    '<span class="landscape-icon" aria-hidden="true">↻</span>',
    '<strong>가로 화면으로 시작</strong>',
    '<p>게임은 가로 화면에 맞춰 제작되어 있습니다.<br>버튼을 누르면 전체화면과 가로 모드를 요청합니다.</p>',
    '<button type="button">가로 화면으로 전환</button>',
    '</div>'
  ].join("");
  document.body.appendChild(gate);

  const button = gate.querySelector("button");
  const isPortrait = () => window.innerHeight > window.innerWidth;

  const updateGate = () => {
    gate.classList.toggle("is-visible", isPortrait());
  };

  const requestLandscape = async () => {
    try {
      if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen({ navigationUI: "hide" });
      }
    } catch (_) {}

    try {
      if (screen.orientation && screen.orientation.lock) {
        await screen.orientation.lock("landscape");
      }
    } catch (_) {}

    window.setTimeout(updateGate, 180);
  };

  button.addEventListener("click", requestLandscape, { passive: true });
  window.addEventListener("resize", updateGate, { passive: true });
  window.addEventListener("orientationchange", () => window.setTimeout(updateGate, 120), { passive: true });
  document.addEventListener("fullscreenchange", updateGate, { passive: true });

  updateGate();
})();
