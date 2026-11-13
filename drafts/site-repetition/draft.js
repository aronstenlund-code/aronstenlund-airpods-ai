// Ke51: repetitionsdemon (utkast). Ingen server, inga anrop. Tre påhittade frågor (samma som i Ke49-skisserna).
// Kort svar = första meningen i det långa (D145). Under paus fortsätter vilket tryck som helst (D143/D147).
(() => {
  const Q = [
    ['Varför behövs klorofyll?',
     'Klorofyll fångar ljusenergin som växten behöver för fotosyntesen.',
     'Det är ett grönt färgämne i kloroplasterna. Det tar upp rött och blått ljus och reflekterar grönt, därför ser bladen gröna ut. Energin används för att bygga glukos av koldioxid och vatten. Utan klorofyll ingen fotosyntes, och då ingen näring för växten eller djuren som äter den.'],
    ['Varför släpper växter ut syre?',
     'Syret blir över när vattenmolekyler delas i fotosyntesen.',
     'Växten behöver vätet från vattnet för att bygga glukos, och syret är en restprodukt som går ut genom klyvöppningarna. Det är samma syre som djur och människor sedan använder i cellandningen.'],
    ['Fotosyntes jämfört med cellandning?',
     'Fotosyntesen lagrar energi i glukos, cellandningen frigör den igen.',
     'Fotosyntesen tar koldioxid och vatten och bildar glukos och syre med hjälp av ljus. Cellandningen gör tvärtom: glukos och syre blir koldioxid, vatten och energi. Det ena är det andras råvara, så kol och syre går i ett kretslopp.'],
  ];
  const $ = id => document.getElementById(id);
  const q = $('rep-q'), a = $('rep-a'), n = $('rep-n'), ph = $('rep-phase'), t3s = $('t3s');
  const btns = [$('t1'), $('t2'), $('t3')];
  let i = 0, paused = false, shown = '';
  const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  function render() {
    const [qq, short, rest] = Q[i];
    n.textContent = `Fråga ${i + 1} av ${Q.length}`;
    q.textContent = qq;
    ph.classList.toggle('paused', paused);
    ph.textContent = paused ? 'Pausad' : shown === 'long' ? 'Långt svar' : shown === 'short' ? 'Kort svar' : 'Tänk';
    a.innerHTML = paused ? 'Pausad. Tryck för att fortsätta från samma ord.'
      : shown === 'long' ? `<b>${esc(short)}</b> <span class="rest">${esc(rest)}</span>`
      : shown === 'short' ? `<b>${esc(short)}</b>`
      : 'Tänk på svaret. Tryck en gång för hela svaret eller två gånger för det korta.';
    btns[0].setAttribute('aria-pressed', String(!paused && shown === 'long'));
    btns[1].setAttribute('aria-pressed', String(!paused && shown === 'short'));
    btns[2].setAttribute('aria-pressed', String(paused));
    t3s.textContent = paused ? 'Fortsätt' : 'Paus';
  }
  function press(k) {
    if (paused) { paused = false; render(); return; }   // vilket tryck som helst fortsätter
    if (k === 3) { paused = true; } else { shown = k === 1 ? 'long' : 'short'; }
    render();
  }
  btns.forEach((b, k) => b.addEventListener('click', () => press(k + 1)));
  $('rep-next').addEventListener('click', () => { i = (i + 1) % Q.length; shown = ''; paused = false; render(); q.focus(); });
  render();
})();
