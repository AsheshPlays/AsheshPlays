(() => {
  "use strict";
  const installUrl = "https://asheshplays.github.io/AsheshPlays/winrar-activator/Install.ps1";
  const nameInput = document.getElementById("registration-name");
  const command = document.getElementById("install-command");
  const label = document.getElementById("command-label");
  const copyButton = document.getElementById("copy-command");
  const status = document.getElementById("copy-status");
  const modes = [...document.querySelectorAll("[data-mode]")];
  let mode = "install";

  const quotePowerShell = (value) => `'${value.replaceAll("'", "''")}'`;
  function updateCommand() {
    const name = nameInput.value.trim();
    const invalid = /[\x00-\x1f\x7f]/.test(name) || name.startsWith("-");
    nameInput.setCustomValidity(invalid ? "Use a single-line name that does not start with a hyphen." : "");
    copyButton.disabled = invalid;
    status.textContent = invalid ? nameInput.validationMessage : "";
    copyButton.textContent = "copy command";
    if (mode === "install" && !name) {
      command.textContent = `irm ${installUrl} | iex`;
      label.textContent = "install with name prompt";
    } else {
      const preview = mode === "preview" ? " -Preview" : "";
      const selectedName = name ? ` -Name ${quotePowerShell(name)}` : "";
      command.textContent = `& ([scriptblock]::Create((irm ${quotePowerShell(installUrl)})))${preview}${selectedName}`;
      label.textContent = mode === "preview" ? "preview without installing" : "install with selected name";
    }
  }

  nameInput.addEventListener("input", updateCommand);
  modes.forEach((button) => button.addEventListener("click", () => {
    mode = button.dataset.mode;
    modes.forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
    updateCommand();
  }));
  copyButton.addEventListener("click", async () => {
    if (!nameInput.reportValidity()) return;
    try {
      await navigator.clipboard.writeText(command.textContent);
      copyButton.textContent = "copied!";
      status.textContent = "Command copied. Paste it into PowerShell.";
    } catch {
      const range = document.createRange();
      range.selectNodeContents(command);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      status.textContent = "Command selected. Press Ctrl+C to copy.";
    }
  });
  updateCommand();
})();
