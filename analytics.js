/* ─────────────────────────────────────────────────────────────
   Mesure d'audience Google Analytics 4, sous consentement.

   GA4 dépose des cookies : en France, la CNIL impose un
   consentement préalable, libre et révocable. Rien n'est donc
   chargé tant que le visiteur n'a pas accepté — ni script, ni
   cookie.

   Pour activer : coller l'identifiant de mesure ci-dessous.
   Tant qu'il est vide, aucune bannière ne s'affiche et le site
   reste strictement sans cookie.
   ───────────────────────────────────────────────────────────── */
window.__GA_ID = '';   /* ex. 'G-XXXXXXXXXX' */

(function () {
  var CLE = 'endenoma-audience';
  var ID  = (window.__GA_ID || '').trim();

  function choix()      { try { return localStorage.getItem(CLE); } catch (e) { return null; } }
  function enregistrer(v){ try { localStorage.setItem(CLE, v); } catch (e) {} }

  /* ── Chargement de GA4, uniquement après acceptation ── */
  function chargerGA() {
    if (!ID || window.__gaCharge) return;
    window.__gaCharge = true;
    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(ID);
    document.head.appendChild(s);
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('js', new Date());
    window.gtag('consent', 'default', {
      ad_storage: 'denied', ad_user_data: 'denied',
      ad_personalization: 'denied', analytics_storage: 'granted'
    });
    window.gtag('config', ID, { anonymize_ip: true });
  }

  /* ── Suppression des cookies GA en cas de refus ultérieur ── */
  function purger() {
    document.cookie.split(';').forEach(function (c) {
      var nom = c.split('=')[0].trim();
      if (/^_ga/.test(nom)) {
        var h = '; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
        document.cookie = nom + '=' + h;
        document.cookie = nom + '=' + h + '; domain=' + location.hostname;
        document.cookie = nom + '=' + h + '; domain=.' + location.hostname;
      }
    });
  }

  function styles() {
    if (document.getElementById('consent-style')) return;
    var st = document.createElement('style');
    st.id = 'consent-style';
    st.textContent = [
      '#consent-bar{position:fixed;left:0;right:0;bottom:0;z-index:6000;',
      'background:#141414;border-top:1px solid #FA06F2;padding:18px 22px;',
      "font-family:'Montserrat','Space Grotesk',system-ui,sans-serif;color:#f0f0f0;",
      'display:flex;gap:18px;align-items:center;justify-content:center;flex-wrap:wrap;}',
      '#consent-bar p{margin:0;font-size:13.5px;line-height:1.6;max-width:620px;color:#e0e0e0;}',
      '#consent-bar a{color:#FA06F2;}',
      '#consent-bar .grp{display:flex;gap:10px;flex-shrink:0;}',
      '#consent-bar button{font:inherit;font-size:12px;font-weight:600;letter-spacing:.14em;',
      'text-transform:uppercase;padding:11px 20px;cursor:pointer;border:1px solid #5a5a5a;',
      'background:none;color:#f0f0f0;transition:background .2s,border-color .2s,color .2s;}',
      '#consent-bar button:hover,#consent-bar button:focus-visible{border-color:#FA06F2;}',
      '#consent-bar button.oui{background:#FA06F2;border-color:#FA06F2;color:#0e0e0e;}',
      '#consent-bar button:focus-visible{outline:2px solid #FA06F2;outline-offset:2px;}',
      '@media(max-width:640px){#consent-bar{flex-direction:column;align-items:stretch;}',
      '#consent-bar .grp{justify-content:stretch;} #consent-bar button{flex:1;}}'
    ].join('');
    document.head.appendChild(st);
  }

  function fermer(bar, precedent) {
    if (bar && bar.parentNode) bar.parentNode.removeChild(bar);
    if (precedent && precedent.focus) { try { precedent.focus(); } catch (e) {} }
  }

  function banniere() {
    if (document.getElementById('consent-bar')) return;
    styles();
    var precedent = document.activeElement;
    var bar = document.createElement('div');
    bar.id = 'consent-bar';
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-live', 'polite');
    bar.setAttribute('aria-label', "Mesure d'audience");
    var cgv = location.pathname.indexOf('/projets/') !== -1 ? '../CGU.html' : 'CGU.html';
    bar.innerHTML =
      '<p>Ce site souhaite mesurer son audience avec Google Analytics, ce qui dépose des cookies. ' +
      'Rien n\'est chargé sans votre accord. Voir l\'<a href="' + cgv + '#art15">article 15 des CGV</a>.</p>' +
      '<div class="grp">' +
      '<button type="button" class="non">Refuser</button>' +
      '<button type="button" class="oui">Accepter</button>' +
      '</div>';
    document.body.appendChild(bar);

    bar.querySelector('.oui').addEventListener('click', function () {
      enregistrer('1'); chargerGA(); fermer(bar, precedent);
    });
    bar.querySelector('.non').addEventListener('click', function () {
      enregistrer('0'); purger(); fermer(bar, precedent);
    });
    /* Échap vaut refus : jamais un consentement par défaut. */
    bar.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { enregistrer('0'); purger(); fermer(bar, precedent); }
    });
    var b = bar.querySelector('.non');
    if (b && b.focus) b.focus();
  }

  /* Permet de revenir sur son choix — appelée depuis les CGV. */
  window.endenomaAudience = function () {
    if (!ID) { return false; }
    try { localStorage.removeItem(CLE); } catch (e) {}
    purger();
    banniere();
    return true;
  };

  function init() {
    if (!ID) return;               /* pas de mesure configurée : pas de bannière */
    var c = choix();
    if (c === '1') { chargerGA(); return; }
    if (c === '0') { return; }
    banniere();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
