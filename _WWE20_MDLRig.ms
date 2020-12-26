(
fname = getOpenFileName types:"VisCon MDL 2019(*.mdl)" \
f = fopen fname "rb"
print f 

fn ReadFixedString bstream fixedLen =
(
        local str = ""
        for i = 1 to fixedLen do
        (
                str += bit.intAsChar (ReadByte bstream #unsigned)
        )
        str
)






clearlistener()
fileMagic = ReadFixedString f 4 --header check

if fileMagic != "MDL!" then (
	messageBox "File is not a valid MDL file." 
	)
else( 
	
		--main
	recPos
	mainTEXT = #() 
	fseek f 36#seek_set
	textSize  = ReadLong f 4
	textCount = ReadLong f 4
	
		--collect TEXT array
		for i = 0 to textCount-1 do (
			fseek f (44+(i*4))#seek_set
			textOffset = ReadLong f 4
			fseek f (44+textOffset+(4*textCount))#seek_set
			textString = ReadString f
			
				
			append mainTEXT textString
		)
		
	recPos = 44+textSize
	fseek f (recPos)#seek_set
	boneSize  = ReadLong f 4 
	boneCount = ReadLong f 4
		
		--collect armature
		tarr = #()
		rarr = #()
		Barr = #()
		Parr = #()	
			
		for i = 0 to boneCount - 1 do (
			fseek f (recPos+8+(i*28))#seek_set
			boneInd = ReadShort f 2
			bonePar = ReadShort f 2
			boneName= mainTEXT[boneInd+1]
			parent  = bonePar
				--get point3 values
			tx = ReadFloat f
			ty = ReadFloat f
			tz = ReadFloat f
			rx = (ReadFloat f * 180) / pi
			ry = (ReadFloat f * 180) / pi
			rz = (ReadFloat f * 180) / pi
			tfm = (eulerangles rx ry rz) as matrix3
			append tarr [tx,ty,tz]
			append rarr tfm	
			append Barr boneName
			append Parr parent
		)
		
		BNArr = #()
		for a = 1 to boneCount Do (
			if isvalidnode (getNodeByName Barr[a]) != true then (
				tfm = rarr[a] 	   --eulerangles
				tfm.row4 = tarr[a] --translation
				if (Parr[a] != -1) do (
					tfm = tfm * BNArr[(Parr[a] + 1)].objecttransform)

				newBone = bonesys.createbone   \
				tfm.row4   \
				(tfm.row4 + 0.01 * (normalize tfm.row1)) \
				(normalize tfm.row3)
				newBone.name = Barr[a]
				newBone.width  = 0.01
				newBone.height = 0.01
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = red
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
			)
		if isvalidnode (getNodeByName Barr[a]) == true then (
			newBone = getNodeByName Barr[a]
		)
		if (Parr[a] != -1) then
			newBone.parent = BNArr[(Parr[a] + 1)]
			append BNArr newBone
		)
		format "BoneCount % \n" boneCount

		
		rootRT = dummy name:"_root" boxsize:[.1,.1,.1]	--rotate armature 90 degrees
		for b in BNArr where b.parent==undefined do b.parent = rootRT
			rootRT.transform = (matrix3 [1,0,0] [0,0,-1] [0,1,0] [0,0,0])	

		recPos = 44+textSize+boneSize+4	
		block_buffer = 0
		MTLsOffset = 0
		
	--find mbfd (skip data-blocks we don't need)
	while (block_buffer != 1147552333) do(
		fseek f (recPos)#seek_set
		block_buffer = ReadLong f 4
		if block_buffer == 558650445 then(
			MTLsOffset = ftell f)
		if block_buffer != 1147552333 do(
			block_size   = ReadLong f 4
			recPos       = recPos+block_size+8))

	--mbfd parse	
		sceneVert_arrays     =#()
		sceneFace_arrays     =#()
		sceneUV_arrays       =#()
		sceneWeight_arrays   =#()
		sceneIndice_arrays   =#()
		sceneNormal_arrays   =#()
		sceneMeshID_arrays   =#()
		sceneIndiceLib_arrays   =#()
		
		mbfdSize   = ReadLong f 4
		modelCount = ReadLong f 4		
		cur_start  = recPos+12
			
			
	--mbfd loop	
	for i=0 to modelCount-1 do(
		fseek f cur_start#seek_set
		
		modelID = ReadLong f 4
		modelName = mainTEXT[modelID+1]
		fseek f (32)#seek_cur
		
		modelVerts  = ReadLong f 4
		modelBlocks = ReadLong f 4

		
		cur_start = cur_start+44	

		mainUDIM = 0
		--mbfd blockLoop (get arrays)
		for i=0 to modelBlocks-1 do(
			fseek f (cur_start)#seek_set
			Vert_array = #()
			Normals_array = #()
			UV_array = #()
			Indices_array = #()
			IndiceLib_array = #()
			Weights_array = #()
			
			block_ = 0
			
			fseek f (12)#seek_cur
			binClass = ReadShort f 2
			binType  = ReadShort f 2
			binFormat= ReadLong  f 4
			
			datClass = mainTEXT[binClass+1]
			datType  = mainTEXT[binType+1]
			datFormat= mainTEXT[binFormat+1]
			
			if (datType == "R32_G32_B32_A32") do (block_ = 16)
			if (datType == "R32_G32_B32") do (block_ = 12)
			if (datType == "R16_G16_B16_A16") do (block_ = 8)
			if (datType == "R8_G8_B8_A8") do (block_ = 4)
			if (datType == "R8") do (block_ = 1)
			if (datType == "R32_G32") do (block_ = 8)

			if (mod modelVerts 4) != 0 and (datType == "R8") then(
				int8  = (ceil (ceil modelVerts / 4) ) * 4
				cur_start = cur_start + (int8 * block_) + 20
			)
			else(
			cur_start = cur_start + (modelVerts * block_) + 20)		--next_block
				
			
			--get data
			if (datClass == "POSITION") do (
				for a=1 to modelVerts do(
					vx = ReadLong f 4
					vy = ReadLong f 4
					vz = ReadLong f 4
						
					vx = bit.intAsFloat vx
					vy = bit.intAsFloat vy
					vz = bit.intAsFloat vz
					
					append Vert_array [vx,-vy,-vz]	)
				append sceneVert_arrays Vert_array 
			)
			if (datClass == "NORMAL") do (	--FixedPoint Q15
				
				if (datType == "R8_G8_B8_A8") then(
					for a=1 to modelVerts do(
						vnx = ReadByte f
						vny = ReadByte f
						vnz = ReadByte f
						null=ReadByte f
						
						vnx = vnx / 128.0
						vny = vny/ 128.0
						vnz = vnz / 128.0
						
						
						append Normals_array [vnx, -vny, -vnz])
					append sceneNormal_arrays Normals_array)
				else if (datType == "R32_G32_B32") then(
					for a=1 to modelVerts do(
						vnx = ReadLong f 4
						vny = ReadLong f 4
						vnz = ReadLong f 4
						
						vnx = bit.intAsFloat vnx
						vny = bit.intAsFloat vny
						vnz = bit.intAsFloat vnz
							
						append Normals_array [vnx,-vny,-vnz]	)
					append sceneNormal_arrays Normals_array )
			)
			
			if (datClass == "TEXCOORD") do (
				
				subUV_Channel = #()
				for a=1 to modelVerts do(
					uvx = ReadFloat f
					uvy = ReadFloat f
					uvw = 0.0
					
					uvy = -1 * (uvy-1.0) 
					
					if (mainUDIM != 1) then(
					append subUV_Channel [uvx , uvy, uvw]	)
					)
					
				if (mainUDIM != 1) then(
					append sceneUV_arrays subUV_Channel	)
				else(
					print "HAS UDIM")
				mainUDIM = 1
			)
			if (datClass == "BLENDINDICES") do (	
				for a=1 to modelVerts do(
					b1 = ReadByte f#unsigned
					b2 = ReadByte f#unsigned
					b3 = ReadByte f#unsigned
					b4 = ReadByte f#unsigned
					
					append Indices_array [b1,b2,b3,b4]
					appendIfUnique  IndiceLib_array b1
					appendIfUnique  IndiceLib_array b2
					appendIfUnique  IndiceLib_array b3
					appendIfUnique  IndiceLib_array b4
					)
				append sceneIndiceLib_arrays IndiceLib_array
				append sceneIndice_arrays Indices_array
			)
			if (datClass == "BLENDWEIGHTS") do (
				if (datType == "R8_G8_B8_A8") then(
					for a=1 to modelVerts do(
						b1 = ReadByte f#unsigned
						b2 = ReadByte f#unsigned
						b3 = ReadByte f#unsigned
						b4 = ReadByte f#unsigned
						
						b1 = b1 / 255.0
						b2 = b2 / 255.0
						b3 = b3 / 255.0
						b4 = b4 / 255.0
						
						append Weights_array [b1,b2,b3,b4])
					append sceneWeight_arrays Weights_array	)
				else if (datType == "R16_G16_B16_A16") then(
					for a=1 to modelVerts do(
						b1 = ReadShort f#unsigned
						b2 = ReadShort f#unsigned
						b3 = ReadShort f#unsigned
						b4 = ReadShort f#unsigned
						
						b1 = b1 / 65535.0
						b2 = b2 / 65535.0
						b3 = b3 / 65535.0
						b4 = b4 / 65535.0
						
						append Weights_array [b1,b2,b3,b4])
					append sceneWeight_arrays Weights_array	)
				else if (datType == "R32_G32_B32_A32") then(
					for a=1 to modelVerts do(
						b1 = ReadLong f 4
						b2 = ReadLong f 4
						b3 = ReadLong f 4
						b4 = ReadLong f 4
						
						b1 = bit.intAsFloat b1
						b2 = bit.intAsFloat b2
						b3 = bit.intAsFloat b3
						b4 = bit.intAsFloat b4
						
						append Weights_array [b1,b2,b3,b4])
					append sceneWeight_arrays Weights_array	)
				
			)
			

			
		)
		
		cur_start = cur_start+(modelVerts* 4)
		fseek f cur_start#seek_set

		--super slow but needed / need to decipher last unk block to properly parse 
		while ( endm_buf != 1296322117) do(
			endm_buf = 0
			endm_buf = ReadLong f 8
		)
		
		cur_start = ftell f + 4
		
	)
	
	--parse LODs (we'll only utilize the highest LOD level)
	for i=0 to modelCount-1 do(
		face_array = #()
		fseek f cur_start#seek_set
		
		if (i == 0) then(
		fseek f 8#seek_cur)
		if (i == 0) then(
		subLODs  = ReadLong f 4)
		
		LODcount = ReadLong f 4
		LODindex = ReadShort f
		
		faceCount= ReadLong f 4
		
		for j=0 to (faceCount/3)-1 do(
			fx = ReadShort f#unsigned
			fy = ReadShort f#unsigned
			fz = ReadShort f#unsigned
			fx = fx + 1
			fy = fy + 1 
			fz = fz + 1
			
			append face_array [fy, fx, fz]
		)
		append sceneFace_arrays face_array
		
		outOff = ftell f
		fseek f (6)#seek_cur
		ModelIndex =  ReadLong f 4
		fseek f ((MTLsOffset+8)+(ModelIndex*4))#seek_set
		ModelIndex =  ReadLong f 4
		meshID = mainTEXT[ModelIndex+1]
		append sceneMeshID_arrays meshID
		fseek f outOff#seek_set
		fseek f (10)#seek_cur
		

		print "face-loop"
		--seekCheck
		cur_start = (ftell f)
		if ((mod cur_start 4) != 0 ) then(
		cur_start  = cur_start + 2)
			
		fseek f cur_start#seek_set
		endm_buf = 0
		
		if ((i+1) != modelCount) then(
		--super slow but needed / need to decipher last unk block to properly parse (this is sorta logical if we look at sublods)
		while ( endm_buf != 1296322117) do(
			endm_buf = 0
			endm_buf = ReadLong f 8
		)
			)
		
		cur_start =  (ftell f)
		
	)
	
	--build meshes
	for i=1 to modelCount do(
		
		try(
			
			msh = mesh vertices:sceneVert_arrays[i] faces:sceneFace_arrays[i]
			msh.name = sceneMeshID_arrays[i]
			msh.numTVerts = sceneUV_arrays[i].count
			buildTVFaces msh
			for j = 1 to sceneUV_arrays[i].count do setTVert msh j sceneUV_arrays[i][j]
			for j = 1 to sceneFace_arrays[i].count do setTVFace msh j sceneFace_arrays[i][j]
			for j = 1 to sceneNormal_arrays[i].count do setNormal msh j sceneNormal_arrays[i][j]	)
		
		catch(format "Unable to build mesh \n")
			
	if msh != undefined then(
		msh.transform = (matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,0])	--rotate 90 degrees
		--append armature
			skinPallette = #()
			max modify mode
			select msh
			skinMod = skin ()
			addModifier msh skinMod
			skinMod.bone_Limit = 4
			
			for j = 1 to sceneIndiceLib_arrays[i].count do(
				   ind = (sceneIndiceLib_arrays[i][j])
				   ind = ind + 1
				   maxbone = BNArr[ind]
				   append skinPallette maxbone
					
				   skinOps.addBone skinMod maxbone 0
				)
			
		--append weights	
			modPanel.setCurrentObject skinMod	
			for j = 1 to sceneVert_arrays[i].count do(
				b2Arr = #()
				w2Arr = #()
				
				for z = 1 to 4 do(
					matrixIndex = findItem skinPallette BNArr[((sceneIndice_arrays[i][j][z])+1)]
					append b2Arr (matrixIndex)
					append w2Arr sceneWeight_arrays[i][j][z]
					)
					
				skinOps.ReplaceVertexWeights skinMod j b2Arr w2Arr	)
				
				
	format "modelCount % \n" modelCount	)		)



fclose f
free f

)

)








