const root = document.documentElement;

const updateScrollProgress = () => {
  const max = root.scrollHeight - window.innerHeight;
  const progress = max > 0 ? window.scrollY / max : 0;
  root.style.setProperty("--scroll", progress.toFixed(4));
};

updateScrollProgress();
window.addEventListener("scroll", updateScrollProgress, { passive: true });
window.addEventListener("resize", updateScrollProgress);

const animatedItems = document.querySelectorAll("[data-animate]");
const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
      }
    });
  },
  { threshold: 0.06, rootMargin: "0px 0px 24% 0px" }
);

animatedItems.forEach((item) => revealObserver.observe(item));

const demoSteps = document.querySelectorAll("[data-demo]");
const demoScenes = document.querySelectorAll("[data-demo-scene]");

const setActiveDemo = (key) => {
  demoSteps.forEach((step) => {
    step.classList.toggle("is-active", step.dataset.demo === key);
  });

  demoScenes.forEach((scene) => {
    scene.classList.toggle("is-active", scene.dataset.demoScene === key);
  });
};

if (demoSteps.length && demoScenes.length) {
  setActiveDemo(demoSteps[0].dataset.demo);

  let demoTicking = false;
  const updateActiveDemo = () => {
    const focusLine = window.innerHeight * 0.48;
    const visibleSteps = Array.from(demoSteps).filter((step) => {
      const rect = step.getBoundingClientRect();
      return rect.bottom > window.innerHeight * 0.16 && rect.top < window.innerHeight * 0.84;
    });

    const stepsToCheck = visibleSteps.length ? visibleSteps : Array.from(demoSteps);
    const activeStep = stepsToCheck
      .map((step) => {
        const rect = step.getBoundingClientRect();
        const center = rect.top + rect.height * 0.5;
        return { step, distance: Math.abs(center - focusLine) };
      })
      .sort((a, b) => a.distance - b.distance)[0]?.step;

    if (activeStep) {
      setActiveDemo(activeStep.dataset.demo);
    }
  };

  const requestDemoUpdate = () => {
    if (demoTicking) return;
    demoTicking = true;
    window.requestAnimationFrame(() => {
      updateActiveDemo();
      demoTicking = false;
    });
  };

  const demoObserver = new IntersectionObserver(
    () => requestDemoUpdate(),
    { threshold: [0.42, 0.58, 0.72], rootMargin: "-18% 0px -34% 0px" }
  );

  demoSteps.forEach((step) => demoObserver.observe(step));
  window.addEventListener("scroll", requestDemoUpdate, { passive: true });
  window.addEventListener("resize", requestDemoUpdate);
  requestDemoUpdate();
}

document.querySelectorAll(".store-button").forEach((button) => {
  button.addEventListener("pointermove", (event) => {
    const rect = button.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width) * 100;
    const y = ((event.clientY - rect.top) / rect.height) * 100;
    button.style.setProperty("--btn-x", `${x.toFixed(1)}%`);
    button.style.setProperty("--btn-y", `${y.toFixed(1)}%`);
  });

  button.addEventListener("pointerleave", () => {
    button.style.removeProperty("--btn-x");
    button.style.removeProperty("--btn-y");
  });
});

const hero = document.querySelector(".hero");
const phone = document.querySelector(".phone");

if (hero && phone && window.matchMedia("(pointer: fine)").matches) {
  hero.addEventListener("pointermove", (event) => {
    const rect = hero.getBoundingClientRect();
    const mx = (event.clientX - rect.left) / rect.width - 0.5;
    const my = (event.clientY - rect.top) / rect.height - 0.5;
    root.style.setProperty("--mx", mx.toFixed(3));
    root.style.setProperty("--my", my.toFixed(3));
  });

  hero.addEventListener("pointerleave", () => {
    root.style.setProperty("--mx", "0");
    root.style.setProperty("--my", "0");
  });
}
