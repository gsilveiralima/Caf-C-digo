
const $ = (s)=>document.querySelector(s);
let state = { subjectKey:null, idx:0, score:0, started:false, data:null, streak:0 };

async function init(){
  const res = await fetch('data/subjects.json');
  state.data = await res.json();
  const list = $('#subjects');
  Object.keys(state.data).forEach(k=>{
    const btn = document.createElement('button');
    btn.className='btn secondary';
    btn.textContent = k;
    btn.onclick = ()=>start(k);
    list.appendChild(btn);
  });
}
function start(key){
  state.subjectKey = key; state.idx=0; state.score=0; state.streak=0; state.started=true;
  $('#intro').style.display='none';
  $('#quiz').style.display='block';
  render();
}
function render(){
  const subject = state.data[state.subjectKey];
  const item = subject.quiz[state.idx];
  $('#subjectName').textContent = state.subjectKey;
  $('#q').textContent = item.q;
  const list = $('#answers'); list.innerHTML='';
  item.a.forEach((txt, i)=>{
    const btn = document.createElement('button');
    btn.className='btn';
    btn.textContent = txt;
    btn.onclick = ()=>answer(i);
    list.appendChild(btn);
  });
  $('#progress').textContent = `Pergunta ${state.idx+1} de ${subject.quiz.length}`;
  $('#score').textContent = `Pontos: ${state.score} | 🔥 Streak: ${state.streak}`;
}
function answer(i){
  const subject = state.data[state.subjectKey];
  const item = subject.quiz[state.idx];
  const isCorrect = i===item.c;
  const feedback = $('#feedback');
  feedback.style.display='block';
  if(isCorrect){
    state.streak+=1;
    const bonus = 100 + (state.streak-1)*25;
    state.score+= bonus;
    feedback.textContent = `✅ Correto! +${bonus} pontos (streak x${state.streak})`;
  } else {
    state.streak=0;
    feedback.textContent = `❌ Ops! Resposta correta: ${item.a[item.c]}`;
  }
  setTimeout(()=>{
    feedback.style.display='none';
    next();
  }, 900);
}
function next(){
  const subject = state.data[state.subjectKey];
  state.idx++;
  if(state.idx>=subject.quiz.length){
    end();
  } else {
    render();
  }
}
function end(){
  $('#quiz').style.display='none';
  $('#final').style.display='block';
  $('#finalScore').textContent = state.score;
}
function restart(){
  $('#final').style.display='none';
  $('#intro').style.display='block';
  $('#subjects').innerHTML='';
  init();
}
window.addEventListener('DOMContentLoaded', init);
