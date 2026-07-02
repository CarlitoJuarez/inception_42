const navToggle = document.getElementById('navToggle');
const navLinks = document.getElementById('navLinks');
const toTop = document.getElementById('toTop');
const filters = document.querySelectorAll('.filter');
const skills = document.querySelectorAll('.skill');
const timelineItems = document.querySelectorAll('.timeline-item');
const educationDetail = document.getElementById('educationDetail');

navToggle.addEventListener('click', () => {
  navLinks.classList.toggle('open');
});

navLinks.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', () => navLinks.classList.remove('open'));
});

filters.forEach(button => {
  button.addEventListener('click', () => {
    filters.forEach(filter => filter.classList.remove('active'));
    button.classList.add('active');

    const selected = button.dataset.filter;
    skills.forEach(skill => {
      const shouldShow = selected === 'all' || skill.dataset.category === selected;
      skill.classList.toggle('hidden', !shouldShow);
    });
  });
});

timelineItems.forEach(item => {
  item.addEventListener('click', () => {
    timelineItems.forEach(entry => entry.classList.remove('active'));
    item.classList.add('active');
    educationDetail.textContent = item.dataset.detail;
  });
});

const revealObserver = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
    }
  });
}, { threshold: 0.14 });

document.querySelectorAll('.reveal').forEach(section => revealObserver.observe(section));

window.addEventListener('scroll', () => {
  toTop.classList.toggle('visible', window.scrollY > 700);
});

toTop.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});
