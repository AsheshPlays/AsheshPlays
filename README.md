<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>AsheshPlays README Demo</title>
  <style>
    body {
      background-color: #121212;
      color: #f7f7f7;
      font-family: 'Fira Code', monospace;
      margin: 0;
      padding: 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    #typing {
      font-size: 2rem;
      font-weight: 700;
      min-height: 2.5rem;
      margin-bottom: 1rem;
      white-space: nowrap;
      overflow: hidden;
      border-right: .15em solid #f7f7f7;
      box-sizing: border-box;
    }
    img {
      margin: 0.5rem;
    }
    .badges img {
      vertical-align: middle;
    }
  </style>
</head>
<body>
  <!-- Dynamic Typing + RGB Color Animation -->
  <div id="header">
    <div id="typing"></div>
  </div>

  <!-- Skill Icons and Snake Animation -->
  <div>
    <a href="https://skillicons.dev">
      <img src="https://skillicons.dev/icons?i=python,django,unity,dotnet,symfony&theme=dark" alt="Skills" />
    </a>
  </div>
  <div>
    <img src="https://raw.githubusercontent.com/AsheshPlays/AsheshPlays/output/github-snake-dark.svg?v=1" alt="Snake animation" />
  </div>

  <!-- Trophies and Badges -->
  <div class="badges">
    <img
      src="https://github-profile-trophy.vercel.app/?username=AsheshPlays&theme=radical&column=7&no-frame=true&no-bg=true&title=-PullRequest,-Reviews"
      alt="GitHub Trophies"
      height="28"
    />
  </div>
  <div class="badges">
    <img
      src="https://komarev.com/ghpvc/?username=AsheshPlays&style=for-the-badge&color=blue&label=Profile%20Visits"
      alt="Profile Visits"
      height="28"
    />
    <img
      src="https://img.shields.io/badge/ASHESH-DEVELOPMENT-red?style=for-the-badge&labelColor=grey"
      alt="Ashesh Development Badge"
      height="28"
    />
    <img
      src="https://img.shields.io/badge/Game_Developer-Expert-gold?style=for-the-badge&logo=unity"
      alt="Game Developer Badge"
      height="28"
    />
  </div>

  <script>
    // Typing effect
    const text = 'ASHESH DEVELOPMENT';
    const typingEl = document.getElementById('typing');
    let idx = 0;
    function type() {
      if (idx <= text.length) {
        typingEl.textContent = text.substring(0, idx);
        idx++;
      } else {
        idx = 0;
      }
    }
    setInterval(type, 150);

    // RGB color animation using HSL cycling
    function animateColor() {
      const hue = (Date.now() / 20) % 360;
      typingEl.style.color = `hsl(${hue}, 100%, 80%)`;
    }
    setInterval(animateColor, 50);
  </script>
</body>
</html>
