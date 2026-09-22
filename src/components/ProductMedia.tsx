import { useEffect, useState, type HTMLAttributes } from 'react';

const PLACEHOLDER='/assets/placeholder-flower.svg';
const isPlaceholder=(src?:string)=>!src||src.includes('placeholder-flower.svg');

type ProductMediaProps={
  imageUrl?:string;
  visualEmoji?:string;
  alt:string;
  className?:string;
  wrapperClassName?:string;
}&HTMLAttributes<HTMLDivElement>;

export function ProductMedia({imageUrl,visualEmoji,alt,className='',wrapperClassName='',...props}:ProductMediaProps){
  const[failed,setFailed]=useState(false);
  useEffect(()=>setFailed(false),[imageUrl]);
  const showEmoji=Boolean(visualEmoji)&&(failed||isPlaceholder(imageUrl));
  const resolvedImage=failed?PLACEHOLDER:(imageUrl||PLACEHOLDER);
  if(showEmoji)return <div {...props} className={`product-emoji-visual ${wrapperClassName}`.trim()} role="img" aria-label={alt}><span>{visualEmoji}</span></div>;
  return <div {...props} className={wrapperClassName}><img className={className} src={resolvedImage} alt={alt} onError={()=>{if(resolvedImage!==PLACEHOLDER)setFailed(true)}}/></div>;
}
