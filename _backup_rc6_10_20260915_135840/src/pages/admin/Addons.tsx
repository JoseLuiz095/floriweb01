import { Edit3, ImagePlus, Plus, Save, Trash2, X } from 'lucide-react';
import { useMemo, useState, type FormEvent } from 'react';
import { useStore } from '../../contexts/StoreContext';
import { ErrorState, LoadingState } from '../../components/ui/AsyncState';
import { ImageWithFallback } from '../../components/ui/ImageWithFallback';
import { useToast } from '../../contexts/ToastContext';
import type { Addon } from '../../types';
import { currency } from '../../utils/format';
import { createId } from '../../utils/id';

const empty=(storeId:string):Addon=>({id:createId(),storeId,name:'',description:'',price:0,active:true,imageUrl:''});

export default function AddonsAdmin(){
  const {addons,products,settings,saveAddon,deleteAddon,uploadAddonImage,loading,error,reloadAdmin}=useStore();
  const {showToast}=useToast();
  const [selected,setSelected]=useState<Addon|null>(null);
  const [draftId,setDraftId]=useState(()=>createId());
  const [imageFile,setImageFile]=useState<File|null>(null);
  const [busy,setBusy]=useState(false);
  const form=selected??{...empty(settings.id),id:draftId};
  const preview=useMemo(()=>imageFile?URL.createObjectURL(imageFile):form.imageUrl||'/assets/placeholder-flower.svg',[imageFile,form.imageUrl]);

  if(loading)return <LoadingState label="Carregando adicionais..."/>;
  if(error)return <ErrorState message={error} onRetry={()=>void reloadAdmin()}/>;

  const clearForm=()=>{setSelected(null);setDraftId(createId());setImageFile(null)};

  const submit=async(e:FormEvent)=>{
    e.preventDefault();
    const formEl=e.currentTarget as HTMLFormElement;
    const fd=new FormData(formEl);
    let addon:Addon={...form,name:String(fd.get('name')||'').trim(),description:String(fd.get('description')||'').trim(),price:Number(fd.get('price')||0),active:fd.get('active')==='on'};
    if(!addon.name){showToast('Informe o nome do adicional.','error');return}
    setBusy(true);
    try{
      if(imageFile){
        const upload=await uploadAddonImage(addon.id,imageFile);
        addon={...addon,imageUrl:upload.url,imageStoragePath:upload.path};
      }
      await saveAddon(addon);
      showToast(selected?'Adicional atualizado.':'Adicional cadastrado.','success');
      clearForm();
      formEl.reset();
    }catch(err){showToast(err instanceof Error?err.message:'Erro ao salvar adicional.','error')}
    finally{setBusy(false)}
  };

  const remove=async(addon:Addon)=>{
    const count=products.filter(p=>p.addons.some(a=>a.id===addon.id)).length;
    if(count&&!confirm(`${addon.name} está vinculado a ${count} produto(s). Remover mesmo assim?`))return;
    try{await deleteAddon(addon.id);showToast('Adicional removido.','success');if(selected?.id===addon.id)clearForm()}
    catch(e){showToast(e instanceof Error?e.message:'Erro ao excluir adicional.','error')}
  };

  const edit=(addon:Addon)=>{setSelected(structuredClone(addon));setImageFile(null)};

  return <>
    <div className="admin-page-title"><div><span className="eyebrow">COMPLEMENTOS</span><h1>Adicionais</h1><p>Cadastre complementos com imagem, descrição e preço para valorizar a experiência de compra.</p></div></div>
    <div className="dashboard-grid categories-grid addons-admin-grid">
      <section className="admin-card no-padding">
        <div className="table-toolbar"><strong>{addons.length} adicionais</strong><span>Imagens ajudam o cliente a decidir</span></div>
        <div className="addon-admin-list">{addons.map(a=><article key={a.id} className="addon-admin-row">
          <ImageWithFallback src={a.imageUrl||'/assets/placeholder-flower.svg'} alt={a.name}/>
          <div className="addon-admin-row__content"><strong>{a.name}</strong><span>{a.description||'Sem descrição'}</span><b>{currency.format(a.price)} · {a.active?'Ativo':'Oculto'}</b></div>
          <div className="row-actions"><button type="button" onClick={()=>edit(a)} aria-label={`Editar ${a.name}`}><Edit3 size={16}/></button><button type="button" onClick={()=>void remove(a)} aria-label={`Excluir ${a.name}`}><Trash2 size={16}/></button></div>
        </article>)}</div>
      </section>

      <section className="admin-card addon-editor-card">
        <div className="admin-card__header"><div><span className="eyebrow">{selected?'EDITAR':'NOVO'} ADICIONAL</span><h2>{selected?'Atualizar adicional':'Adicionar complemento'}</h2></div>{selected&&<button type="button" className="icon-button" onClick={clearForm}><X size={18}/></button>}</div>
        <form className="stack-form" key={selected?.id??draftId} onSubmit={submit}>
          <div className="addon-image-editor"><ImageWithFallback src={preview} alt="Prévia do adicional"/><div><strong>Imagem do adicional</strong><span>JPG, PNG ou WEBP · até 5 MB</span><label className="secondary-button"><ImagePlus size={16}/>Selecionar imagem<input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e)=>setImageFile(e.target.files?.[0]??null)}/></label></div></div>
          <label>Nome<input name="name" required defaultValue={form.name} placeholder="Ex.: Chocolate 90g"/></label>
          <label>Descrição<textarea name="description" rows={3} defaultValue={form.description}/></label>
          <label>Preço<input name="price" type="number" min="0" step="0.01" required defaultValue={form.price}/></label>
          <label className="mini-check"><input name="active" type="checkbox" defaultChecked={form.active}/>Adicional ativo</label>
          <button className="primary-button" disabled={busy} type="submit">{selected?<Save size={18}/>:<Plus size={18}/>} {busy?'Salvando...':selected?'Salvar alterações':'Adicionar adicional'}</button>
        </form>
      </section>
    </div>
  </>;
}
