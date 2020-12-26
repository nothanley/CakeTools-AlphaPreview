(
clearlistener()
fn existFile fname = (getfiles fname).count != 0
fn round_to val n =
(
local mult = 10.0 ^ n
(floor ((val * mult) + 0.5)) / mult
)

MDLOut = GetSaveFileName types:"VisCon MDL 2019(*.mdl)"
skelFile = getOpenFileName types:"VisCon MDL 2019(*.mdl)"
skelFile = fopen skelFile "rb"

if (existFile MDLOut == 0) then( 
	mdlFile = createfile MDLOut
	close mdlFile
	free mdlFile
	mdlFile = fopen MDLOut "wb")
else(
	deletefile MDLOut
	mdlFile = fopen MDLOut "wb"
)

selModels  = for obj in getCurrentSelection() where (classof obj == Editable_mesh) collect obj
modelCount = (selModels).count
format "Model Count: % \n\n\n" modelCount

fn ListSkinBones obj toNode:false = 
( 
    skinMod
    bonesList = #()
    result
    -------------------------------------------------------------------------------
 
    clearSelection()
    max modify mode
 
    hiddenState = obj.ishidden 
    obj.ishidden = false
    select obj
 
    skinMod = obj.modifiers[#skin]
    modPanel.setCurrentObject obj.modifiers[#Skin]
 
    bonesList = for i=1 to (skinOps.GetNumberBones skinMod) collect (skinOps.GetBoneName skinMod i 0)
 
    obj.ishidden = hiddenState 
    result = bonesList 
 
    result
)	

fn basicTEXTtemplate textList =(
	append textList "POSITION"
	append textList "R32_G32_B32"
	append textList "float"
	append textList "NORMAL"
	append textList "R8_G8_B8_A8"
	append textList "snorm"
	append textList "TANGENT"
	append textList "BINORMAL"
	append textList "R8"
	append textList "COLOR"	
	append textList "unorm"
	append textList "TEXCOORD"
	append textList "R32_G32"
	append textList "R16_G16_B16_A16"
	append textList "BLENDINDICES"
	append textList "uint"
	append textList "BLENDWEIGHTS"
	append textList "R32_G32_B32_A32"
	
	return textList
)
	--Collect External Skeleton
	boneID    = #() 
	boneDat   = #() 
	bonePrt   = #() 

	fseek skelFile 36#seek_set
	skelFileTEXTsize  = ReadLong skelFile 4
	skelFileTEXTcount = ReadLong skelFile 4
	skelFileTEXT  = #()
	fseek skelFile (4*skelFileTEXTcount)#seek_cur
	for i=1 to skelFileTEXTcount do(
		str = ReadString skelFile
		append skelFileTEXT str
	)
	fseek skelFile (32+skelFileTEXTsize+8)#seek_set
	header = ReadLong skelFile 4

	if (header != 1162760002) then (
		messageBox "No Bones found.")
	else(
		fseek skelFile 4#seek_cur
		boneCount = ReadLong skelFile 4
		for i=1 to boneCount do(
			boneArr = #()
			boneIndex = ReadShort skelFile 2
			ParrIndex = ReadShort skelFile 2
			boneText  = skelFileTEXT[boneIndex+1]
			if ParrIndex != -1 then(
			boneText2 = skelFileTEXT[ParrIndex])
			else(
			boneText2 = "NULL")
			
			posX = ReadLong skelFile 4
			posY = ReadLong skelFile 4
			posZ = ReadLong skelFile 4
			eulerX= ReadLong skelFile 4
			eulerY= ReadLong skelFile 4
			eulerZ= ReadLong skelFile 4
			
			append boneArr posX
			append boneArr posY
			append boneArr posZ
			append boneArr eulerX
			append boneArr eulerY
			append boneArr eulerZ
			append boneID boneText
			append bonePrt boneText2
			append boneDat boneArr
		)
	)	
	
	clearlistener()
	print "THING"
	







_rootNode = for obj in objects   where (classof obj == dummy) collect obj

if (_rootNode.count > 1) then(
	messageBox "Scene has multiple _root nodes." 
)

mainTEXT  = #()
sizeTEXT  = #()
mainShape = #()

allTheBones = for obj in objects   where (classof obj == BoneGeometry) collect obj
allTheModel = for obj in selModels collect obj.name
bonePallette= for x in allTheBones collect x.name
for var in bonePallette do( append mainTEXT var )
for var in allTheModel do( append mainTEXT var )


for obj in selModels do( append mainShape "M_Outfit" )
append mainTEXT mainShape[1]
basicTEXTtemplate mainTEXT
if modelCount > 1 do( for i=2 to mainShape.count do( append mainTEXT mainShape[i]))

size = 0
for var in mainTEXT do(
	append sizeTEXT size
	size = size + var.count + 1)
indloop = size
if (mod indloop 4) != 0 then(	indloop  = (ceil (ceil indloop / 4) ) * 4)	
	

print mainTEXT

clearlistener()
if modelCount != 0 then(
	sceneLODs = #()
	IKBool = #()
	--getSceneBonePallette
	
	WriteLong   mdlFile 558646349 #unsigned 
	WriteLong   mdlFile 29 #unsigned 
	WriteLongLong mdlFile 0xC344AC1CC2ABE56D
	WriteLongLong mdlFile 0x42ABE5A2C1A77A25
	WriteLongLong mdlFile 0x4173DB8CBF9AB021
	
	WriteLong   mdlFile 0x54584554 #unsigned 
	WriteLong   mdlFile ((indloop+((mainTEXT.count)*4))+4) #unsigned 
	WriteLong   mdlFile mainTEXT.count #unsigned 
	
	for var in sizeTEXT do(
		WriteLong mdlFile var #unsigned
	)
	for var in mainTEXT do(
		WriteString mdlFile var
	)
	for i=1 to (indloop-size) do(
		WriteByte mdlFile 0
	)
	
	if (bonePallette.count) != 0 do(
		WriteLong	mdlFile 0x454E4F42 #unsigned --BONE
		WriteLong	mdlFile (((bonePallette.count) * 28)+4) #unsigned
		WriteLong	mdlFile (bonePallette.count) #unsigned
		
		print "BONE STUFF"

		for i=1 to bonePallette.count do(
			bn     = allTheBones[i]
			bnIndex= findItem mainTEXT bonePallette[i]
			extIndex=findItem boneID bonePallette[i] 
			
			bnPar = bn.parent
			if (bnPar.name != "_root") then(
				pIndex    = findItem mainTEXT bnPar.name 
				extpIndex = findItem boneID bnPar.name )
			else( pIndex = "NULL" )

			
			WriteShort mdlFile (bnIndex-1) #unsigned
			if (pIndex != "NULL") then( WriteShort mdlFile (pIndex-1) #unsigned)
			else( WriteShort mdlFile (65535) #unsigned)
			
			for i=1 to 6 do(
				bnD   = boneDat[ extIndex ][i]
				WriteLong mdlFile bnD #unsigned 
			)
		)
	)
	
	WriteLong mdlFile 0x214c544d #unsigned 
	WriteLong mdlFile ((modelCount*4)+4)#unsigned 
	WriteLong mdlFile (modelCount)#unsigned 
	for i = 1 to modelCount do(
		WriteLong mdlFile ((bonePallette.count+i)-1) #unsigned
	)
	
	format "Model: % % \n" subObjName subObjVerts --subObjFaces
	mbfd_size = 4
	lods_size = 12
	binormals = 0
	for i = 1 to modelCount do(
		msh = (selModels)[i]
		hasSkin = (for m in msh.modifiers where isKindOf m skin collect m).count
		print hasSkin
		
		nv  = getnumverts msh
		binormals = nv
		if (mod binormals 4) != 0 then(	binormals  = (ceil (ceil binormals / 4) ) * 4)	
		
			
		if hasSkin !=0 then(
			mbfd_size = mbfd_size + 44 + (20+(12*nv)) + (20+(12*nv)) + (20+(4*nv)) + (20+(1*binormals)) + (20+(8*nv)) + (20+(4*nv)) + (20+(4*nv)) + (16+(4*nv)) )
		else( mbfd_size = mbfd_size + 44 + (20+(12*nv)) + (20+(12*nv)) + (20+(4*nv)) + (20+(1*binormals)) + (20+(8*nv)) + (16+(4*nv)) + 4)
		
	)
	for i = 1 to modelCount do(
		msh = (selModels)[i]
		nf  = getNumFaces msh
		
		
		lods_size = lods_size + ((6 + ((nf * 3)*2) + 26))*2
		
		face_size = ((nf * 3) * 2)

		if (mod face_size 4) != 0 then( lods_size = lods_size - 4)
	)
	
	
	
	
	--------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	WriteLong mdlFile 0x4466424D #unsigned 
	WriteLong mdlFile mbfd_size #unsigned 
	WriteLong mdlFile modelCount #unsigned 
	for i = 1 to modelCount do(
		boneIndices = #()
		boneWeights = #()
		mshVerts  = #()
		mshFaces  = #()
		mshNormals= #()
		mshUDIMS  = #()
		mshTVerts = #()
		
		--collect basic data
		msh = (selModels)[i]
		subObjName  = msh.name
		subObjVerts = msh.numverts
		
		binormals = subObjVerts
		if (mod binormals 4) != 0 then(	binormals  = (ceil (ceil binormals / 4) ) * 4)	
		
		if (i = 1) then( WriteLong mdlFile (bonePallette.count + modelCount)#unsigned)
		else( WriteLong mdlFile (mainTEXT.count-(modelCount-1)+(i-1))#unsigned)
		
		WriteLong mdlFile (256)#unsigned
		WriteLong mdlFile (0)#unsigned 		
		WriteLongLong mdlFile (0)#unsigned 
		WriteLongLong mdlFile (0)#unsigned
		WriteLongLong mdlFile (0)#unsigned 
		
			
		--armature
		hasSkin = (for m in msh.modifiers where isKindOf m skin collect m).count
		format "hasSkin = %\n" hasSkin
		append IKBool hasSkin
		
		if hasSkin != 0 then(
			
			skinMod = msh.modifiers["skin"]
			max modify mode
			modPanel.setCurrentObject skinMod
			
			skinMod.bone_Limit = 4
			for v = 1 to (skinOps.GetNumberVertices skinMod) do(
				indiceArr = #()
				weightArr = #()
				for j = 1 to (skinOps.GetVertexWeightCount skinMod v) do(
					boneID   = (skinOps.GetVertexWeightBoneID skinMod v j) 
					boneName = (skinOps.GetBoneName skinMod boneID 0)
					VertWeight = (skinOps.GetVertexWeight skinMod v j)
					boneIndex  = (findItem bonePallette boneName)-1
					
					if indiceArr.count < 4 then(
					append indiceArr boneIndex
					append weightArr VertWeight)
				)

				--get zero weights
				if (indiceArr.count < 4) then(
					for x=1 to (4-indiceArr.count) do(
						append indiceArr 0
						append weightArr 0
					)
				)
				append boneIndices indiceArr
				append boneWeights weightArr
			)
		)
		else(
			append boneIndices 0
			append boneWeights 0
		)
		--msh = convertToMesh msh
		subObjFaces = getNumFaces msh
		
		WriteLong mdlFile (subObjVerts)#unsigned
		WriteLong mdlFile (5 + (hasSkin*2))#unsigned
		
		for x = 1 to subObjVerts do(
			v  = getVert msh x
			vn = getNormal msh x
			append mshVerts v
			append mshNormals vn

		)
		for x = 1 to subObjFaces do(
			f = getFace msh x
			append mshFaces f
		)
		append sceneLODs mshFaces
		for x = 1 to subObjVerts do( 		
			vt = meshop.getMapVert msh 1 x
			append mshTVerts vt
		)
		print mshFaces.count
		print mshVerts.count
		print mshNormals.count
		print mshTVerts.count
			
		format "Model: % % \n" subObjName subObjVerts subObjFaces
			POSITION = (finditem mainTEXT "POSITION")
			R32_G32_B32 = (finditem mainTEXT "R32_G32_B32")
			NORMAL = (finditem mainTEXT "NORMAL")
			snorm = (finditem mainTEXT "snorm")
			R8 = (finditem mainTEXT "R8")
			BINORMAL = (finditem mainTEXT "BINORMAL")
			float_ = (finditem mainTEXT "float")
			R32_G32 = (finditem mainTEXT "R32_G32")
			TEXCOORD = (finditem mainTEXT "TEXCOORD")
			TANGENT = (finditem mainTEXT "TANGENT")
			unorm = (finditem mainTEXT "unorm")
			R8_G8_B8_A8 = (finditem mainTEXT "R8_G8_B8_A8")
			BLENDWEIGHTS = (finditem mainTEXT "BLENDWEIGHTS")
			BLENDINDICES = (finditem mainTEXT "BLENDINDICES")
			R8_G8_B8_A8 = (finditem mainTEXT "R8_G8_B8_A8")
			R16_G16_B16_A16 = (finditem mainTEXT "R16_G16_B16_A16")
			R32_G32_B32_A32 = (finditem mainTEXT "R32_G32_B32_A32")
			uint = (finditem mainTEXT "uint")
		
		WriteLong mdlFile (0x5a1acea4)#unsigned--posHash
		WriteLong mdlFile (0x25207d67)#unsigned---r32g32b32Hash
		WriteLong mdlFile (0x47b58e5f)#unsigned---floatHash 	
		WriteShort mdlFile (POSITION-1)#unsigned--posHash
		WriteShort mdlFile (R32_G32_B32-1)#unsigned---r32g32b32Hash
		WriteLong mdlFile (float_-1)#unsigned---floatHash 	
		
		for i=1 to subObjVerts do(
			vx = mshVerts[i][1]
			vy = mshVerts[i][2]
			vz = mshVerts[i][3]
			
			
			WriteFloat mdlFile (vx*1.0)
			WriteFloat mdlFile (vz*-1.0)
			WriteFloat mdlFile (vy*1.0)
		)
		
		WriteLong mdlFile (0x24992F14)#unsigned--posHash
 		WriteLong mdlFile (0x25207d67)#unsigned---r32g32b32Hash
		WriteLong mdlFile (0x47b58e5f)#unsigned---floatHash 	
		WriteShort mdlFile (NORMAL-1)#unsigned
		WriteShort mdlFile (R32_G32_B32-1)#unsigned
		WriteLong mdlFile (float_-1)

		for i=1 to subObjVerts do(
			vNx = mshNormals[i][1] 
			vNy = mshNormals[i][2]
			vNz = mshNormals[i][3]
			vNx = vNx * 1.0
			vNy = vNy * 1.0
			vNz = vNz * -1.0
			vNx = bit.floatAsInt vNx 
			vNy = bit.floatAsInt vNy
			vNz = bit.floatAsInt vNz 
			
			WriteLong mdlFile vNx
			WriteLong mdlFile vNz 
			WriteLong mdlFile vNy
		)
		
		WriteLong mdlFile (0x622888B3)#unsigned--posHash
		WriteLong mdlFile (0x767C77E0)#unsigned---r32g32b32Hash
		WriteShort mdlFile (0x58AA)		
		WriteShort mdlFile (0xCC6A)	
		WriteShort mdlFile (TANGENT-1)#unsigned--posHash
		WriteShort mdlFile (R8_G8_B8_A8-1)#unsigned---r32g32b32Hash
		WriteLong mdlFile (snorm-1)#unsigned---floatHash 

		for i=1 to subObjVerts do(
			WriteByte mdlFile 0 
			WriteByte mdlFile 0 
			WriteByte mdlFile 0
			WriteByte mdlFile 0
		)
		
		WriteLong mdlFile (0x1B21E0AD)#unsigned--posHash
		WriteShort mdlFile (0x82C5)		
		WriteShort mdlFile (0xD347)	
		WriteShort mdlFile (0x58AA)		
		WriteShort mdlFile (0xCC6A)		
		WriteShort mdlFile (BINORMAL-1)#unsigned--posHash
		WriteShort mdlFile (R8-1)#unsigned---r32g32b32Hash
		WriteLong mdlFile (snorm-1)#unsigned---floatHash 

		for i=1 to binormals do(
			WriteByte mdlFile 127 #signed
		)
		
		WriteLong mdlFile (0x3C7BA159)#unsigned--posHash
		WriteLong mdlFile (0x7F450227)#unsigned---r32g32b32Hash
		WriteLong mdlFile (0x47B58E5F)#unsigned---floatHash 	
		WriteShort mdlFile (TEXCOORD-1)#unsigned--posHash
		WriteShort mdlFile (R32_G32-1)#unsigned---r32g32b32Hash
		WriteLong mdlFile (float_-1)#unsigned---floatHash 

		for i=1 to subObjVerts do(
			uvx = mshTVerts[i][1]
			uvy = mshTVerts[i][2]
			uvw = mshTVerts[i][3]
			
			uvy = -1 * (-1.0 + uvy)
			uvx = bit.floatAsInt uvx 
			uvy = bit.floatAsInt uvy
			
			WriteLong mdlFile uvx
			WriteLong mdlFile uvy
		)
		if hasSkin != 0 then(

			
			WriteLong mdlFile (0x6B8F6EB3)#unsigned
			WriteLong mdlFile (0x767C77E0)#unsigned
			WriteLong mdlFile (0x02938935)#unsigned
			WriteShort mdlFile (BLENDINDICES-1)#unsigned
			WriteShort mdlFile (R8_G8_B8_A8-1)#unsigned
			WriteLong mdlFile (uint-1)#unsigned

			for a=1 to subObjVerts do(
				boneIndices[a]
				
				for k=1 to 4 do(
					ind = boneIndices[a][k]
					WriteByte mdlFile ind #unsigned
				)
			)
			WriteLong mdlFile (0x498F1A9B)#unsigned
			WriteLong mdlFile (0x767C77E0)#unsigned
			WriteLong mdlFile (0x5C0D3942)#unsigned
			WriteShort mdlFile (BLENDWEIGHTS-1)#unsigned
			WriteShort mdlFile (R8_G8_B8_A8-1)#unsigned --altered
			WriteLong mdlFile (unorm-1)#unsigned

			for a=1 to subObjVerts do(
				boneWeights[a]
				
				for k=1 to 4 do(
					weight = boneWeights[a][k]
					
					WriteByte mdlFile (weight * 255.0) #unsigned
				)
			)
			
		)
		
		for a=1 to subObjVerts do(
			WriteLong mdlFile (0)#unsigned
		)
			
			WriteLong mdlFile (0x0)#unsigned
			WriteLong mdlFile (0x1A)#unsigned
			WriteLong mdlFile (0x4D444E45)#unsigned
			WriteLong mdlFile (0x0)#unsigned
	)		
	
	
	
	
	
	
	--------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------
	WriteLong mdlFile 0x73444f4c #unsigned 
	WriteLong mdlFile (lods_size)#unsigned
	WriteLong mdlFile (2)#unsigned
	for i = 1 to modelCount do(
		if (i==1) then(
		WriteLong mdlFile (modelCount)#unsigned)
		WriteShort mdlFile (i-1)#unsigned
		WriteLong mdlFile ((sceneLODS[i].count)*3)#unsigned
		
		for x=1 to sceneLODS[i].count do (
			fx = (sceneLODS[i][x][1])-1 
			fy = (sceneLODS[i][x][2])-1
			fz = (sceneLODS[i][x][3])-1
			
			WriteShort mdlFile (fy)#unsigned
			WriteShort mdlFile (fx)#unsigned
			WriteShort mdlFile (fz)#unsigned
		)
			face_size = (((sceneLODS[i].count)*3) * 2)
			if (mod face_size 4) == 0 then( 
			WriteShort mdlFile (0)#unsigned)

			WriteLong  mdlFile (1)#unsigned
			WriteLong  mdlFile (i-1)#unsigned
			WriteLong  mdlFile (0)#unsigned
			WriteLong mdlFile ((sceneLODS[i].count)*3)#unsigned
			WriteLong mdlFile 0x4D444E45 #unsigned 
			WriteLong mdlFile 0 #unsigned 					)
		
		
		
		
	for i = 1 to modelCount do(
		if (i==1) then(
			WriteLong mdlFile (modelCount)#unsigned)
			WriteShort mdlFile (i-1)#unsigned
			WriteLong mdlFile ((sceneLODS[i].count)*3)#unsigned
			
		for x=1 to sceneLODS[i].count do (
			fx = (sceneLODS[i][x][1])-1 
			fy = (sceneLODS[i][x][2])-1
			fz = (sceneLODS[i][x][3])-1 
			
			WriteShort mdlFile (fy)#unsigned
			WriteShort mdlFile (fx)#unsigned
			WriteShort mdlFile (fz)#unsigned
		)
			face_size = (((sceneLODS[i].count)*3) * 2)
			if (mod face_size 4) == 0 then( 
			WriteShort mdlFile (0)#unsigned)
			
			WriteLong  mdlFile (1)#unsigned
			WriteLong  mdlFile (i-1)#unsigned
			WriteLong  mdlFile (0)#unsigned
			WriteLong mdlFile ((sceneLODS[i].count)*3)#unsigned
			WriteLong mdlFile 0x4D444E45 #unsigned 
			WriteLong mdlFile 0 #unsigned 			)
			
			
		
	WriteLong mdlFile 0x21444E45 #unsigned 
	WriteLong mdlFile 0 #unsigned 
)
else( 
	messageBox "No Objects selected." 
)

fclose mdlFile
free mdlFile

messageBox "MDL! Exported Succesfully."	

)





