//
//  main.m
//  FTPushMedia
//
//  Created by ZWS on 14-11-12.
//  Copyright (c) 2014年 FTSafe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#import "Utilities.h"
#import "libavutil/avstring.h"
#import "libavcodec/avcodec.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "simplest_ffmpeg_audio_encoder.h"
#include "libavutil/time.h"

/**
 *◊ÓºÚµ•µƒª˘”⁄FFmpegµƒ“Ù∆µ±‡¬Î∆˜
 *Simplest FFmpeg Audio Encoder
 *
 *¿◊œˆÊË Lei Xiaohua
 *leixiaohua1020@126.com
 *÷–π˙¥´√Ω¥Û—ß/ ˝◊÷µÁ ”ºº ı
 *Communication University of China / Digital TV Technology
 *http://blog.csdn.net/leixiaohua1020
 *
 *±æ≥Ã–Ú µœ÷¡À“Ù∆µPCM≤…—˘ ˝æ›±‡¬ÎŒ™—πÀı¬Î¡˜£®MP3£¨WMA£¨AACµ»£©°£
 * «◊ÓºÚµ•µƒFFmpeg“Ù∆µ±‡¬Î∑Ω√ÊµƒΩÃ≥Ã°£
 *Õ®π˝—ßœ∞±æ¿˝◊”ø…“‘¡ÀΩ‚FFmpegµƒ±‡¬Î¡˜≥Ã°£
 *This software encode PCM data to AAC bitstream.
 *It's the simplest audio encoding software based on FFmpeg.
 *Suitable for beginner of FFmpeg
 */

#include <stdio.h>

#define __STDC_CONSTANT_MACROS

#ifdef _WIN32
//Windows
extern "C"
{
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
};
#else
//Linux...
#ifdef __cplusplus
extern "C"
{
#endif
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#ifdef __cplusplus
};
#endif
#endif
#import "Utilities.h"
#import "simplest_ffmpeg_audio_encoder.h"
int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index){
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_audio2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame){
            ret=0;
            break;
        }
        printf("Flush Encoder: Succeed to encode 1 frame!\tsize:%5d\n",enc_pkt.size);
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

int testM()
{
    AVFormatContext* pFormatCtx;
    AVOutputFormat* fmt;
    AVStream* audio_st;
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    
    uint8_t* frame_buf;
    AVFrame* pFrame;
    AVPacket pkt;
    
    int got_frame=0;
    int ret=0;
    int size=0;
    
    FILE *in_file=NULL;	                        //Raw PCM data
    int framenum=1000;                          //Audio frame number
    //	const char* out_file = "tdjm.aac";          //Output URL
    int i;
    const char* out_file = [[Utilities documentsPath:@"tdjm.aac"] cStringUsingEncoding:NSASCIIStringEncoding];
    const char *in_filename  = [[Utilities bundlePath:@"tdjm.pcm"] cStringUsingEncoding:NSASCIIStringEncoding];
//    in_file= fopen("tdjm.pcm", "rb");
    in_file= fopen(in_filename, "rb");
    
    av_register_all();
    
    //Method 1.
    pFormatCtx = avformat_alloc_context();
    fmt = av_guess_format(NULL, out_file, NULL);
    pFormatCtx->oformat = fmt;
    
    
    //Method 2.
    //avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    //fmt = pFormatCtx->oformat;
    
    //Open output URL
    if (avio_open(&pFormatCtx->pb,out_file, AVIO_FLAG_READ_WRITE) < 0){
        printf("Failed to open output file!\n");
        return -1;
    }
    
    audio_st = avformat_new_stream(pFormatCtx, 0);
    if (audio_st==NULL){
        return -1;
    }
    pCodecCtx = audio_st->codec;
    pCodecCtx->codec_id = fmt->audio_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
    pCodecCtx->sample_fmt = AV_SAMPLE_FMT_S16;
    pCodecCtx->sample_rate= 44100;
    pCodecCtx->channel_layout=AV_CH_LAYOUT_STEREO;
    pCodecCtx->channels = av_get_channel_layout_nb_channels(pCodecCtx->channel_layout);
    pCodecCtx->bit_rate = 64000;
    pCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    pCodecCtx->profile = FF_PROFILE_AAC_MAIN;
    //Show some information
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec){
        printf("Can not find encoder!\n");
        return -1;
    }
    if (avcodec_open2(pCodecCtx, pCodec,NULL) < 0){
        printf("Failed to open encoder!\n");
        return -1;
    }
    pFrame = av_frame_alloc();
    pFrame->nb_samples= pCodecCtx->frame_size;
    pFrame->format= pCodecCtx->sample_fmt;
    
    size = av_samples_get_buffer_size(NULL, pCodecCtx->channels,pCodecCtx->frame_size,pCodecCtx->sample_fmt, 1);
    frame_buf = (uint8_t *)av_malloc(size);
    avcodec_fill_audio_frame(pFrame, pCodecCtx->channels, pCodecCtx->sample_fmt,(const uint8_t*)frame_buf, size, 1);
    
    //Write Header
    avformat_write_header(pFormatCtx,NULL);
    
    av_new_packet(&pkt,size);
    
    for (i=0; i<framenum; i++){
        //Read PCM
        if (fread(frame_buf, 1, size, in_file) <= 0){
            printf("Failed to read raw data! \n");
            return -1;
        }else if(feof(in_file)){
            break;
        }
        pFrame->data[0] = frame_buf;  //PCM Data
        
        pFrame->pts=i*100;
        got_frame=0;
        //Encode
        ret = avcodec_encode_audio2(pCodecCtx, &pkt,pFrame, &got_frame);
        if(ret < 0){
            printf("Failed to encode!\n");
            return -1;
        }
        if (got_frame==1){
            printf("Succeed to encode 1 frame! \tsize:%5d\n",pkt.size);
            pkt.stream_index = audio_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
    
    //Flush Encoder
    ret = flush_encoder(pFormatCtx,0);
    if (ret < 0) {
        printf("Flushing encoder failed\n");
        return -1;
    }
    
    //Write Trailer
    av_write_trailer(pFormatCtx);
    
    //Clean
    if (audio_st){
        avcodec_close(audio_st->codec);
        av_free(pFrame);
        av_free(frame_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
    
    return 0;
}



int select_channel_layout(AVCodec *codec);
int select_sample_rate(AVCodec *codec)
{
    const int *p;
    int best_samplerate = 0;
    
    if (!codec->supported_samplerates)
        return 44100;
    
    p = codec->supported_samplerates;
    while (*p) {
        best_samplerate = FFMAX(*p, best_samplerate);
        p++;
    }
    return best_samplerate;
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}



int flush_encoder2(AVFormatContext *fmt_ctx,unsigned int stream_index)
{
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
          CODEC_CAP_DELAY))
        return 0;
    while (1) {
        printf("Flushing stream #%u encoder\n", stream_index);
        //ret = encode_write_frame(NULL, stream_index, &got_frame);
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
                                     NULL, &got_frame);
        av_frame_free(NULL);
        if (ret < 0)
            break;
        if (!got_frame)
        {ret=0;break;}
        printf("编码成功1帧！\n");
        /* mux encoded frame */
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0)
            break;
    }
    return ret;
}

int main122(int argc, char * argv[])
{
    //    return mainT(argc, argv);
    
    
    AVFormatContext* pFormatCtx;
    AVOutputFormat* fmt;
    AVStream* video_st;
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    
    uint8_t* picture_buf;
    AVFrame* picture;
    int size;
    
    const char *in_filename  = [[Utilities bundlePath:@"src01_480x272.yuv"] cStringUsingEncoding:NSASCIIStringEncoding];
    FILE *in_file = fopen(in_filename, "rb");	//视频YUV源文件
    int in_w=480,in_h=272;//宽高
    int framenum=20;
    const char* out_file = [[Utilities bundlePath:@"m2.MOV"] cStringUsingEncoding:NSASCIIStringEncoding];					//输出文件路径 @"outf.h264"
    out_file = "rtmp://172.18.1.203/live/t2";//输出 URL（Output URL）[RTMP]
    
    av_register_all();
    
    avformat_network_init();
    //方法1.组合使用几个函数
    pFormatCtx = avformat_alloc_context();
    //猜格式
    //    fmt = av_guess_format(NULL, out_file, NULL);
    //    pFormatCtx->oformat = fmt;
    
    //方法2.更加自动化一些
    //    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    avformat_alloc_output_context2(&pFormatCtx, NULL, "flv", out_file); //RTMP
    fmt = pFormatCtx->oformat;
    
    
    //注意输出路径
    int error = avio_open(&pFormatCtx->pb,out_file, AVIO_FLAG_WRITE);
    if (error < 0)
    {
        printf("输出文件打开失败");
        return -1;
    }
    
    video_st = avformat_new_stream(pFormatCtx, 0);
    if (video_st==NULL)
    {
        return -1;
    }
    pCodecCtx = video_st->codec;
    pCodecCtx->codec_id = fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = PIX_FMT_YUV420P;
    pCodecCtx->width = in_w;
    pCodecCtx->height = in_h;
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;
    pCodecCtx->bit_rate = 400000;
    pCodecCtx->gop_size=250;
    //H264
    //pCodecCtx->me_range = 16;
    //pCodecCtx->max_qdiff = 4;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    //pCodecCtx->qcompress = 0.6;
    //输出格式信息
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec)
    {
        printf("没有找到合适的编码器！\n");
        return -1;
    }
    if (avcodec_open2(pCodecCtx, pCodec,NULL) < 0)
    {
        printf("编码器打开失败！\n");
        return -1;
    }
    picture = avcodec_alloc_frame();
    size = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    picture_buf = (uint8_t *)av_malloc(size);
    avpicture_fill((AVPicture *)picture, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    //写文件头
    avformat_write_header(pFormatCtx,NULL);
    
    AVPacket pkt;
    int y_size = pCodecCtx->width * pCodecCtx->height;
    av_new_packet(&pkt,y_size*3);
    
    for (int i=0; i<framenum; i++){
        //读入YUV
        if (fread(picture_buf, 1, y_size*3/2, in_file) < 0)
        {
            printf("文件读取错误\n");
            return -1;
        }else if(feof(in_file)){
            break;
        }
        picture->data[0] = picture_buf;  // 亮度Y
        picture->data[1] = picture_buf+ y_size;  // U
        picture->data[2] = picture_buf+ y_size*5/4; // V
        //PTS
        picture->pts=i;
        int got_picture=0;
        //编码
        int ret = avcodec_encode_video2(pCodecCtx, &pkt,picture, &got_picture);
        if(ret < 0)
        {
            printf("编码错误！\n");
            return -1;
        }
        if (got_picture==1)
        {
            printf("编码成功第%d帧！\n",i);
            pkt.stream_index = video_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
    
    //Flush Encoder
    //    int ret = flush_encoder(pFormatCtx,0);
    //    if (ret < 0) {
    //        printf("Flushing encoder failed\n");
    //        return -1;
    //    }
    
    //写文件尾
    av_write_trailer(pFormatCtx);
    
    //清理
    if (video_st)
    {
        avcodec_close(video_st->codec);
        av_free(picture);
        av_free(picture_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
    
    return 0;
}



/***
 ***/
//static void SaveFrame(AVFrame *pFrame, int width, int height, int iFrame)
//{
//    FILE *pFile;
//    char szFilename[255];
//    int  y;
//
//    // Open file
//    memset(szFilename, 0, sizeof(szFilename));
//    snprintf(szFilename, 255, "./bmptest/%03d.ppm", iFrame);
//    system("mkdir -p ./bmptest");
//    pFile=fopen(szFilename, "wb");
//    if(pFile==NULL)
//        return;
//
//    // Write header
//    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
//
//    // Write pixel data
//    for(y = 0; y < height; y++)
//        fwrite(pFrame->data[0]+y*pFrame->linesize[0], 1, width*3, pFile);
//
//    // Close file
//    fclose(pFile);
//}
//
//
//int mainT(int argc, char **argv)
//{
//    AVFormatContext *pFormatCtx = NULL;
//    int err, i;
//    char *filename = "alan.mp4"; // argv[1];
//    AVCodec *pCodec = NULL;
//    AVCodecContext *pCodecCtx;
//    AVFrame *pFrame;
//    AVFrame *pFrameRGB;
//    uint8_t *buffer;
//    int numBytes;
//    int frameFinished;
//    AVPacket packet;
//    int videoStream;
//    struct SwsContext *pSwsCtx;
//
//    av_log_set_level(AV_LOG_DEBUG);
//
//    av_log(NULL, AV_LOG_INFO, "Playing: %s\n", filename);
//
//    av_register_all();
//
//    pFormatCtx = avformat_alloc_context();
//    //    pFormatCtx->interrupt_callback.callback = decode_interrupt_cb;
//    //    pFormatCtx->interrupt_callback.opaque = NULL;
//    err = avformat_open_input(&pFormatCtx, filename, NULL, NULL);
//    if (err < 0) {
//        av_log(NULL, AV_LOG_ERROR, "open_input fails, ret = %d\n", err);
//        return -1;
//    }
//
//    err = avformat_find_stream_info(pFormatCtx, NULL);
//    if (err < 0) {
//        av_log(NULL, AV_LOG_WARNING, "could not find codec\n");
//        return -1;
//    }
//
//    av_dump_format(pFormatCtx, 0, filename, 0);
//
//    av_log(NULL, AV_LOG_INFO, "nb_streams in %s = %d\n", filename, pFormatCtx->nb_streams);
//    videoStream = -1;
//    for (i = 0; i < pFormatCtx->nb_streams; i++) {
//        if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
//            videoStream=i;
//            av_log(NULL, AV_LOG_DEBUG, "video stream index = %d\n", i,
//                   pFormatCtx->streams[i]->codec->codec_type);
//            break;
//        }
//    }
//    if(videoStream==-1) {
//        av_log(NULL, AV_LOG_ERROR, "Haven't find video stream.\n");
//        return -1; // Didn't find a video stream
//    }
//
//    // Find decoder
//    pCodecCtx=pFormatCtx->streams[i]->codec;
//    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
//    if (!pCodec) {
//        av_log(NULL, AV_LOG_ERROR, "%s: avcodec_find_decoder fails\n", filename);
//        return -1;
//    }
//
//    // Open pCodec
//    if(avcodec_open(pCodecCtx, pCodec)<0) {
//        av_log(NULL, AV_LOG_ERROR, "%s: avcodec_open fails\n", filename);
//        return -1; // Could not open codec
//    }
//
//    // Allocate video frame
//    pFrame=avcodec_alloc_frame();
//    if(pFrame == NULL)
//        return -1;
//
//    // Allocate an AVFrame structure
//    pFrameRGB = avcodec_alloc_frame();
//    if(pFrameRGB == NULL)
//        return -1;
//
//    // Determine required buffer size and allocate buffer
//    numBytes = avpicture_get_size(PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height);
//    buffer = (uint8_t *)av_malloc(numBytes * sizeof(uint8_t));
//    avpicture_fill((AVPicture *)pFrameRGB, buffer, PIX_FMT_RGB24,
//                   pCodecCtx->width, pCodecCtx->height);
//
//    pSwsCtx = sws_getContext (pCodecCtx->width,
//                              pCodecCtx->height,
//                              pCodecCtx->pix_fmt,
//                              pCodecCtx->width,
//                              pCodecCtx->height,
//                              PIX_FMT_RGB24,
//                              SWS_BICUBIC,
//                              NULL, NULL, NULL);
//    i=0;
//    while(av_read_frame(pFormatCtx, &packet) >= 0) {
//        if(packet.stream_index == videoStream) { // Is this a packet from the video stream?
//            avcodec_decode_video2(pCodecCtx,
//                                  pFrame,
//                                  &frameFinished,
//                                  &packet); // Decode video frame
//
//            if(frameFinished) { // Did we get a video frame?
//                av_log(NULL, AV_LOG_DEBUG, "Frame %d decoding finished.\n", i);
//                // Save the frame to disk
//                if(i++ < 5) {
//                    //转换图像格式，将解压出来的YUV的图像转换为BRG24的图像
//                    sws_scale(pSwsCtx,
//                              pFrame->data,
//                              pFrame->linesize,
//                              0,
//                              pCodecCtx->height,
//                              pFrameRGB->data,
//                              pFrameRGB->linesize);
//                    // 保存为PPM
//                    SaveFrame(pFrameRGB, pCodecCtx->width, pCodecCtx->height, i);
//                }
//                else {
//                    break;
//                }
//            }
//            else {
//                av_log(NULL, AV_LOG_DEBUG, "Frame not finished.\n");
//            }
//        }
//
//        av_free_packet(&packet); // Free the packet that was allocated by av_read_frame
//    }
//    sws_freeContext (pSwsCtx);
//
//    av_free (pFrame);
//    av_free (pFrameRGB);
//    av_free (buffer);
//    avcodec_close (pCodecCtx);
//    av_close_input_file (pFormatCtx);
//    return 0;
//}

int mainee(int argc, char **argv)
{
    //    if(argc < 3)
    //    {
    //        printf("argc number is error\n");
    //        return 0;
    //    }
    
    av_register_all();
    AVCodecContext *encodecCtx = NULL;
    AVCodec *encodec;
    AVPacket enpacket;
    AVFrame *avframe;
    int gotframeptr;
    
    int frame_size = 0;
    int *samples = 0;
    int SAMPLESIZE = 0;
    encodec = avcodec_find_encoder(CODEC_ID_AAC);
    if(!encodec)
    {
        fprintf(stderr, "Unsupported encodec!\n");
        return -1;
    }
    encodecCtx= avcodec_alloc_context3(encodec);
    
    encodecCtx->channels = 2;
    encodecCtx->sample_fmt = AV_SAMPLE_FMT_FLTP;
    encodecCtx->sample_rate = 44100;
    encodecCtx->bit_rate = 128000;
    encodecCtx->profile = FF_PROFILE_AAC_LOW;
    encodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    
    
    if((avcodec_open2(encodecCtx, encodec, NULL) < 0))
    {
        fprintf(stderr, "can't open  encodec!\n");
        return -1;
    }
    
    
    
    FILE *fin = NULL;
    
    const char *in_filename  = [[Utilities bundlePath:@"11.wav"] cStringUsingEncoding:NSASCIIStringEncoding];
    fin = fopen(in_filename,"rb");
    if(!fin)
    {
        printf("open fin file error\n");
        return 0;
    }
    
    //    FILE *fout = NULL;
    //    fout = fopen(argv[2],"a+");
    //    if(!fout)
    //    {
    //        printf("open fout file error\n");
    //        return 0;
    //    }
    
    avframe = av_frame_alloc();
  	 if (!avframe)
     {
         fprintf(stderr, "Could not allocate audio frame\n");
         exit(1);
     }
    
    avframe->nb_samples     = encodecCtx->frame_size;
    avframe->format         = encodecCtx->sample_fmt;
    avframe->channel_layout = encodecCtx->channel_layout;
    int buffer_size = av_samples_get_buffer_size(NULL, encodecCtx->channels,
                                                 encodecCtx->frame_size,
                                                 encodecCtx->sample_fmt, 0);
    printf("--%d---%d\n",encodecCtx->frame_size,buffer_size);
    
   	samples = av_malloc(buffer_size);
   	
    if (!samples)
    {
        fprintf(stderr, "Could not allocate %d bytes for samples buffer\n",
                buffer_size);
        exit(1);
   	}
    /* setup the data pointers in the AVFrame */
    int ret = avcodec_fill_audio_frame(avframe, encodecCtx->channels, encodecCtx->sample_fmt,
                                       (const uint8_t*)samples, buffer_size, 0);
    if (ret < 0)
    {
        fprintf(stderr, "Could not setup audio frame\n");
        exit(1);
    }
    
    
    
    AVFormatContext* pFormatCtx;
    //方法2.更加自动化一些
    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, in_filename);
    AVStream* audio_st;
    audio_st = avformat_new_stream(pFormatCtx, 0);
    if (audio_st==NULL){
        return -1;
    }
    
    //输出格式信息
    av_dump_format(pFormatCtx, 0, in_filename, 1);
    
    //memset(out_buf,0,encodecCtx->frame_size*8);
    int size;
    int len;
    int got_output;
    av_init_packet(&enpacket);
    enpacket.data = NULL;
    enpacket.size = 0;
    while(1)
    {
        size = fread(samples,1,buffer_size,fin);
        if(size == 0)
        {
            printf("read elf\n");
            break;
        }
        
        len = avcodec_encode_audio2(encodecCtx,&enpacket,avframe,&got_output);
        printf("1111---%d__1111__%d1111__%d\n",size,len,enpacket.size);
        if(got_output)
        {
            //            int num = fwrite(enpacket.data,1,enpacket.size,fout);
            //            if(num == 0)
            //            {
            //                printf("write error\n");
            //                sleep(1);
            //            }
            av_free_packet(&enpacket);
            av_init_packet(&enpacket);
            enpacket.data = NULL;
            enpacket.size = 0;
            printf("222222222222222222222222\n");
        }
        //memset(out_buf,0,FF_MIN_BUFFER_SIZE);
    }
    av_free_packet(&enpacket);
    free(samples);
    //    fclose(fout);
    fclose(fin);
    return 0;
}

static const int avf_time_base = 1000000;
AVRational avf_time_base_qq = {
    .num = 1,
    .den = avf_time_base
};

int main111(int argc, char* argv[])
{
    AVFormatContext* pFormatCtx;
    AVOutputFormat* fmt;
    AVStream* audio_st;
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    
    uint16_t* frame_buf, *frame_buf_tmp;
    AVFrame* frame;
    int size;
    
    const char *in_filename  = [[Utilities bundlePath:@"k32b16c1.pcm"] cStringUsingEncoding:NSASCIIStringEncoding];
    const char* out_file = [[Utilities documentsPath:@"32.aac"] cStringUsingEncoding:NSASCIIStringEncoding];      //输出文件路径
    
    FILE *in_file = fopen(in_filename, "rb");    //音频PCM采样数据
    int framenum=1000;  //音频帧数
    
    
    av_register_all();
    
    //    //方法1.组合使用几个函数
    //    pFormatCtx = avformat_alloc_context();
    //    //猜格式
    //    fmt = av_guess_format(NULL, out_file, NULL);
    //    pFormatCtx->oformat = fmt;
    
    
    //方法2.更加自动化一些
    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    fmt = pFormatCtx->oformat;
    
    //注意输出路径
    if (avio_open(&pFormatCtx->pb,out_file, AVIO_FLAG_READ_WRITE) < 0)
    {
        printf("输出文件打开失败！\n");
        return -1;
    }
    
    audio_st = avformat_new_stream(pFormatCtx, 0);
    if (audio_st==NULL){
        return -1;
    }
    
    
    pCodecCtx = audio_st->codec;
    pCodecCtx->codec_id = fmt->audio_codec;
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec)
    {
        printf("没有找到合适的编码器！\n");
        return -1;
    }
    //    pCodec->channel_layouts = AV_CH_LAYOUT_MONO;
    
    pCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
    pCodecCtx->sample_fmt = AV_SAMPLE_FMT_FLTP;
    pCodecCtx->sample_rate= 44100;//select_sample_rate( );//44100; 32000
    pCodecCtx->channel_layout= AV_CH_LAYOUT_MONO;//select_channel_layout(pCodec);//AV_CH_LAYOUT_MONO;//select_channel_layout(pCodec); //AV_CH_LAYOUT_STEREO;
    pCodecCtx->channels = av_get_channel_layout_nb_channels(pCodecCtx->channel_layout);
    pCodecCtx->bit_rate = 62828;//512000;//64000; 62828
    pCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    pCodecCtx->bits_per_coded_sample = 16;
    
    //输出格式信息
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    
    if (avcodec_open2(pCodecCtx, pCodec,NULL) < 0)
    {
        printf("编码器打开失败！\n");
        return -1;
    }
    frame = av_frame_alloc();
    frame->nb_samples= pCodecCtx->frame_size;
    frame->format= pCodecCtx->sample_fmt;
    
    size = av_samples_get_buffer_size(NULL, pCodecCtx->channels,pCodecCtx->frame_size,pCodecCtx->sample_fmt, 1);
    frame_buf = av_malloc(size);
    frame_buf_tmp = av_malloc(size);
    avcodec_fill_audio_frame(frame, pCodecCtx->channels, pCodecCtx->sample_fmt,(const uint8_t*)frame_buf, size, 1);
    
    //写文件头
    avformat_write_header(pFormatCtx,NULL);
    
    AVPacket pkt;
    av_new_packet(&pkt,size);
    
    int got_frame=0;
    float t, tincr;int i;
    int ret;
    t = tincr = 2 * M_PI * 440.0 / pCodecCtx->sample_rate;
    int64_t first_audio_pts = av_gettime();
    for ( i=0; i<100; i++)
#if 1
    {
        av_init_packet(&pkt);
        pkt.data = NULL; // packet data will be allocated by the encoder
        pkt.size = 0;
        
        for (int j = 0; j < pCodecCtx->frame_size; j++) {
            int tmp = (int)(sin(t) * 10000);
            frame_buf[2*j] = tmp;
            
            for (int k = 1; k < pCodecCtx->channels; k++)
                frame_buf[2*j + k] = frame_buf[2*j];
            t += tincr;
        }
        
        //        frame->pts=i*100;
        /* encode the samples */
        do{
            ret = avcodec_encode_audio2(pCodecCtx, &pkt, frame, &got_frame);
        }while (!got_frame);
        
        
        if (ret < 0) {
            fprintf(stderr, "Error encoding audio frame\n");
            exit(1);
        }
        int64_t tt = av_gettime();
        pkt.pts = pkt.dts = av_rescale_q(tt - first_audio_pts,
                                         AV_TIME_BASE_Q,
                                         avf_time_base_qq);
        if (got_frame==1)
        {
            printf("编码成功第%d帧！\n",i);
            pkt.stream_index = audio_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
#else
    {
        av_init_packet(&pkt);
        pkt.data = NULL; // packet data will be allocated by the encoder
        pkt.size = 0;
        //读入PCM
        //        int n = (int)fread(frame_buf, 1, size, in_file);
        int n = (int)fread(frame_buf_tmp, sizeof(uint16_t), pCodecCtx->frame_size, in_file);
        
        for (int j = 0; j < pCodecCtx->frame_size; j++) {
            uint16_t tmp = frame_buf_tmp[j];
            frame_buf[2*j] = tmp;
            
            for (int k = 1; k < pCodecCtx->channels; k++)
                frame_buf[2*j + k] = frame_buf[2*j];
            //                        t += tincr;
        }
        
        if ( n < 0)
        {
            printf("文件读取错误！\n");
            return -1;
        }else if(feof(in_file)){
            break;
        }
        //        frame->data[0] = frame_buf;  //采样信号
        
        //        frame->pts=i*100;
        //编码
        
        
        do{
            ret = avcodec_encode_audio2(pCodecCtx, &pkt, frame, &got_frame);
        }while (!got_frame);
        //        int ret = avcodec_encode_audio2(pCodecCtx, &pkt, frame, &got_frame);
        if(ret < 0)
        {
            printf("编码错误！\n");
            return -1;
        }
        
        int64_t tt = av_gettime();
        pkt.pts = pkt.dts = av_rescale_q(tt - first_audio_pts,
                                         AV_TIME_BASE_Q,
                                         avf_time_base_qq);
        if (got_frame==1)
        {
            printf("编码成功第%d帧！\n",i);
            pkt.stream_index = audio_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
#endif
    /* get the delayed frames */
    for (got_frame = 1; got_frame; i++) {
        ret = avcodec_encode_audio2(pCodecCtx, &pkt, NULL, &got_frame);
        if (ret < 0) {
            fprintf(stderr, "Error encoding frame\n");
            exit(1);
        }
        int64_t tt = av_gettime();
        pkt.pts = pkt.dts = av_rescale_q(tt - first_audio_pts,
                                         AV_TIME_BASE_Q,
                                         avf_time_base_qq);
        if (got_frame) {
            printf("delayed 编码成功第%d帧！\n",i);
            pkt.stream_index = audio_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
    
    
    //写文件尾
    av_write_trailer(pFormatCtx);
    
    //清理
    if (audio_st)
    {
        avcodec_close(audio_st->codec);
        av_free(frame);
        av_free(frame_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
    
    return 0;
}

int main1(int argc, char* argv[])
{
    
    testM();
    return 0;
    AVFormatContext* pFormatCtx;
    AVOutputFormat* fmt;
    AVStream* audio_st;
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    
    uint8_t* frame_buf;
    AVFrame* frame;
    int size;
    const char *in_filename  = [[Utilities bundlePath:@"bj8k16b.pcm"] cStringUsingEncoding:NSASCIIStringEncoding];
    FILE *in_file = fopen(in_filename, "rb");    //音频PCM采样数据
    int framenum=1000;  //音频帧数
    const char* out_file = [[Utilities documentsPath:@"32.aac"] cStringUsingEncoding:NSASCIIStringEncoding];      //输出文件路径
    
    
    av_register_all();
    
    //方法1.组合使用几个函数
    //    pFormatCtx = avformat_alloc_context();
    //    //猜格式
    //    fmt = av_guess_format(NULL, out_file, NULL);
    //    pFormatCtx->oformat = fmt;
    
    
    //方法2.更加自动化一些
    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
    fmt = pFormatCtx->oformat;
    
    //注意输出路径
    if (avio_open(&pFormatCtx->pb,out_file, AVIO_FLAG_READ_WRITE) < 0)
    {
        printf("输出文件打开失败！\n");
        return -1;
    }
    
    audio_st = avformat_new_stream(pFormatCtx, 0);
    if (audio_st==NULL){
        return -1;
    }
    pCodecCtx = audio_st->codec;
    pCodecCtx->codec_id = fmt->audio_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
    pCodecCtx->sample_fmt = AV_SAMPLE_FMT_FLTP;
    pCodecCtx->sample_rate= 8000;
    pCodecCtx->channel_layout=AV_CH_LAYOUT_MONO;//AV_CH_LAYOUT_STEREO AV_CH_LAYOUT_MONO
    pCodecCtx->channels = av_get_channel_layout_nb_channels(pCodecCtx->channel_layout);
    pCodecCtx->bit_rate = 6000;
    pCodecCtx->strict_std_compliance = FF_COMPLIANCE_EXPERIMENTAL;
    
    //输出格式信息
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec)
    {
        printf("没有找到合适的编码器！\n");
        return -1;
    }
    if (avcodec_open2(pCodecCtx, pCodec,NULL) < 0)
    {
        printf("编码器打开失败！\n");
        return -1;
    }
    frame = av_frame_alloc();
    frame->nb_samples= pCodecCtx->frame_size;
    frame->format= pCodecCtx->sample_fmt;
    
    size = av_samples_get_buffer_size(NULL, pCodecCtx->channels,pCodecCtx->frame_size,pCodecCtx->sample_fmt, 1);
    frame_buf = (uint8_t *)av_malloc(size);
    avcodec_fill_audio_frame(frame, pCodecCtx->channels, pCodecCtx->sample_fmt,(const uint8_t*)frame_buf, size, 1);
    
    //写文件头
    avformat_write_header(pFormatCtx,NULL);
    
    AVPacket pkt;
    av_new_packet(&pkt,size);
    
    for (int i=0; i<framenum; i++){
        //读入PCM
        if (fread(frame_buf, 1, size, in_file) < 0)
        {
            printf("文件读取错误！\n");
            return -1;
        }else if(feof(in_file)){
            break;
        }
        frame->data[0] = frame_buf;  //采样信号
        
        frame->pts=i*100;
        int got_frame=0;
        
        if (av_new_packet(&pkt, size) < 0) {
            return AVERROR(EIO);
        }
        //编码
        int ret = avcodec_encode_audio2(pCodecCtx, &pkt,frame, &got_frame);
        if(ret < 0)
        {
            printf("编码错误！\n");
//            return -1;
        }
        if (got_frame==1)
        {
            printf("编码成功第%d帧！\n",i);
            pkt.stream_index = audio_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_free_packet(&pkt);
        }
    }
    
    //写文件尾
    av_write_trailer(pFormatCtx);
    
    //清理
    if (audio_st)
    {
        avcodec_close(audio_st->codec);
        av_free(frame);
        av_free(frame_buf);
    }
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
    
    return 0;
}


int select_channel_layout(AVCodec *codec)
{
    const uint64_t *p;
    uint64_t best_ch_layout = 0;
    int best_nb_channels   = 0;
    
    if (!codec->channel_layouts)
        return AV_CH_LAYOUT_STEREO;
    
    p = codec->channel_layouts;
    while (*p) {
        int nb_channels = av_get_channel_layout_nb_channels(*p);
        
        if (nb_channels > best_nb_channels) {
            best_ch_layout    = *p;
            best_nb_channels = nb_channels;
        }
        p++;
    }
    return best_ch_layout;
}
