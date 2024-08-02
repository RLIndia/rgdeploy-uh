import AWS from 'aws-sdk';
import archiver from 'archiver';
import stream from 'stream';
import util from 'util';

// Initialize S3 client
const s3 = new AWS.S3();

export const handler = async (event) => {
    const reqBody = JSON.parse(event.body);
    const sourceBucket = reqBody.sourceBucket;
    const sourcePrefix = reqBody.sourcePrefix;
    const destinationBucket = reqBody.destinationBucket;
    const destinationPrefix = reqBody.destinationPrefix;

    console.log(reqBody)
    try {
        console.log(`ziping and uploading files from ${sourcePrefix} to ${destinationPrefix}`)

        // List objects in the source S3 folder
        const listParams = {
            Bucket: sourceBucket,
            Prefix: sourcePrefix
        };
        const listedObjects = await s3.listObjectsV2(listParams).promise();

        if (listedObjects.Contents.length === 0) {
            console.log('No files found in the source folder');
            return { statusCode: 404, body: 'No files found in the source folder' };
        }

        // Create a PassThrough stream for archiver
        const passThroughStream = new stream.PassThrough();
        
        // Set up the zip archive
        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        archive.pipe(passThroughStream);

        // Function to add files to the archive
        const addFilesToArchive = async () => {
            for (const obj of listedObjects.Contents) {
                const fileKey = obj.Key;
                const fileStream = s3.getObject({ Bucket: sourceBucket, Key: fileKey }).createReadStream();
                const filePath = fileKey.replace(sourcePrefix, '');
                console.log(`obj = ${JSON.stringify(obj)}`)
                console.log(`filePath = ${filePath}`)
                if(filePath == "" || filePath == null || filePath == undefined){
                    continue;
                }
                archive.append(fileStream, { name: filePath });
            }

            await archive.finalize();
        };

        // Start adding files to the archive
        await addFilesToArchive();

        // Upload the zip to the destination S3 bucket
        const uploadParams = {
            Bucket: destinationBucket,
            Key: destinationPrefix,
            Body: passThroughStream,
            ContentType: 'application/zip'
        };

        const uploadPromise = s3.upload(uploadParams).promise();

        await uploadPromise;

        console.log('Zip file created and uploaded successfully')
        return {
            statusCode: 200,
            body: 'Zip file created and uploaded successfully'
        };

    } catch (error) {
        console.error('Error creating or uploading zip file',error);
        return {
            statusCode: 500,
            body: 'Error creating or uploading zip file'
        };
    }
};
