/* Client feedback: opens a pre-filled GitHub issue form on the public design repo.
   Free on any Vercel plan; the reviewer needs a free GitHub account. */
(function () {
  const ST = window.ST = window.ST || {};
  ST.FEEDBACK_REPO = 'https://github.com/Emmaco08/solutiontee-cbt-design';

  /** URL of the feedback form, pre-filled with the screen name and link. */
  ST.feedbackUrl = (screen) => {
    const where = screen || document.title.replace(/ · .*$/, '');
    const q = new URLSearchParams({
      template: 'feedback.yml',
      title: `[Feedback] ${where}`,
      screen: `${where} (${location.href})`
    });
    return `${ST.FEEDBACK_REPO}/issues/new?${q}`;
  };
  ST.openFeedback = screen => window.open(ST.feedbackUrl(screen), '_blank', 'noopener');
})();
